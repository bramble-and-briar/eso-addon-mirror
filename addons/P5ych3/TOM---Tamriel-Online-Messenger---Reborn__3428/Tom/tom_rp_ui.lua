--	TOM Reborn - Roleplay - Panel (v6.5.0)
--	✅ P5YCH3: New file. The Roleplay panel (Roleplay button, /tomrp or the key binding) and the small progress bar shown while a post is sent.
--	The frame and bar are declared in tom.xml. Keyboard UI only.

tomRP = tomRP or {}
local RP = tomRP
local UI = {}
RP.UI = UI
local L = RP.L
local Splitter = RP.Splitter
local Chat = RP.Chat
local Q = RP.Queue

-- colours of TOM's windows
local COLOR_TEXT = { 0.88, 0.88, 0.88, 1 }
local COLOR_HEAD = { 0.88, 0.88, 0.63, 1 }
local COLOR_DIM = { 0.62, 0.62, 0.62, 1 }
local COLOR_WARN = { 1, 0.45, 0.35, 1 }
local COLOR_GOOD = { 0.55, 0.85, 0.55, 1 }

local EDITOR_CAP = 1000000
local c = {}									-- all controls
UI.controls = c
local initialized = false
local tab = "compose"
local edits = {}								-- every edit box, so they can all be un-focused together
local controlId = 0
local destList = {}							-- the destinations offered right now
local destIndex = 1
local whisperShown = false						-- is the whisper name box in use (kept here, the layout does not read it back from the controls)
local previewParts, previewInfo, previewIndex, previewError = nil, nil, 1, nil
local analyzeToken = 0
local undoText
local clearArmed, deleteArmed, libDeleteArmed = false, false, false
local sentenceSetting, paragraphSetting, tagSetting, soundSetting, everySetting = true, false, false, true, true
local notice = ""
local libSelected, sessionSelectedId
local historyPage, historyKey, historyNewest, historyNewestFirst = 1, nil, nil, nil
local participantDraft
local loadingParticipants = false
local HISTORY_PAGE_SIZE = 10

--===============================================================================================================
-- SMALL HELPERS
--===============================================================================================================
local function controlName() controlId = controlId + 1; return "tomRPControl" .. controlId end

local function fmt(number)
	if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(number) end
	return tostring(number)
end

local function plain(value) return (tostring(value or ""):gsub("|", "")) end

local function showTip(control, text)
	InitializeTooltip(InformationTooltip, control, TOPRIGHT, 0, 5, BOTTOMRIGHT)
	SetTooltipText(InformationTooltip, text)
end

-- Adds a tooltip without replacing any handler the template already has.
local function tip(control, text)
	ZO_PreHookHandler(control, "OnMouseEnter", function(self) showTip(self, text) end)
	ZO_PreHookHandler(control, "OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

local function makeControl(parent, kind, x, y, width, height, template)
	local item
	if template then item = WINDOW_MANAGER:CreateControlFromVirtual(controlName(), parent, template)
	else item = WINDOW_MANAGER:CreateControl(controlName(), parent, kind) end
	item:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
	item:SetDimensions(width, height)
	item.rpParent, item.rpW, item.rpH = parent, width, height
	return item
end

local function label(parent, text, x, y, width, height, font, color)
	local item = makeControl(parent, CT_LABEL, x, y, width, height or 22)
	item:SetFont(font or "ZoFontGame")
	local col = color or COLOR_TEXT
	item:SetColor(col[1], col[2], col[3], col[4])
	item:SetText(text or "")
	return item
end

local function setColor(item, col) item:SetColor(col[1], col[2], col[3], col[4]) end

local function button(parent, text, x, y, width, callback, height)
	local item = makeControl(parent, CT_BUTTON, x, y, width, height or 28, "ZO_DefaultButton")
	item:SetFont("ZoFontGame")
	item:SetText(text)
	item:SetHandler("OnClicked", callback)
	item:SetDrawLevel(5)	-- ✅ P5YCH3: v6.5.0 - a button is always drawn above whatever sits next to it
	return item
end

local function edit(parent, x, y, width, height, multiline, cap)
	local backdrop = makeControl(parent, CT_BACKDROP, x, y, width, height, multiline and "ZO_MultiLineEditBackdrop_Keyboard" or "ZO_SingleLineEditBackdrop_Keyboard")
	local item = WINDOW_MANAGER:CreateControlFromVirtual(controlName(), backdrop, multiline and "ZO_DefaultEditMultiLineForBackdrop" or "ZO_DefaultEditForBackdrop")
	item:SetMaxInputChars(cap or EDITOR_CAP)
	if multiline then item:SetNewLineEnabled(true) end
	edits[#edits + 1] = item
	item.backdrop = backdrop
	return item
end

local function blur() for _, item in ipairs(edits) do item:LoseFocus() end end

local function combo(parent, x, y, width, onSelect)
	local container = makeControl(parent, CT_CONTROL, x, y, width, 28, "ZO_ComboBox")
	local box = ZO_ComboBox_ObjectFromContainer(container)
	box:SetFont("ZoFontGame")
	box:SetSortsItems(false)
	box.container = container
	return box
end

local function setNotice(message)
	notice = tostring(message or "")
	if initialized and c.status then c.status:SetText(plain(notice)) end
end
function UI.Notify(message) setNotice(message) end

--===============================================================================================================
-- ANALYSIS: split the composer text into parts and show them
--===============================================================================================================
local function effectiveMax()
	local limit, err = Chat.GetLimit()
	if not limit then return nil, err end
	local configured = RP.sv.maxChars
	if type(configured) == "number" and configured > 0 then return math.min(configured, limit), nil, limit end
	return limit, nil, limit
end

local function splitterOptions(max)
	return { maxChars = max, reserve = RP.sv.tag and Splitter.TAG_LEN or 0, prefix = RP.sv.prefix, suffix = RP.sv.suffix,
		sentences = RP.sv.sentences, paragraphs = RP.sv.paragraphs, everyPart = RP.sv.everyPart }
end

-- Message for a splitter refusal key (detail is the part number for STARTS_COMMAND).
local function refusal(key, detail)
	if key == "STARTS_COMMAND" then return L("E_STARTS_COMMAND", detail or 1) end
	if key == "MARKER_TYPE" or key == "MARKER_BAD" or key == "MARKER_PIPE" or key == "MARKER_LINE" then return L("E_MARKER") end
	return L("E_" .. tostring(key))
end

local function analyze(text)
	local max, err = effectiveMax()
	if not max then return nil, nil, err end
	local parts, info, detail = Splitter.Split(text, splitterOptions(max))
	if not parts then return nil, nil, refusal(info, detail) end
	return parts, info
end

local function showPreview()
	if not initialized then return end
	local total = previewParts and #previewParts or 0
	previewIndex = math.max(1, math.min(previewIndex, math.max(total, 1)))
	if total > 0 then
		local length = previewInfo.lengths[previewIndex] + (RP.sv.tag and Splitter.TAG_LEN or 0)
		local sent = Q.active and Q.IsConfirmed and Q.IsConfirmed(previewIndex)
		c.previewTitle:SetText(L("PREVIEW_TITLE", previewIndex, total, length, previewInfo.limit + (RP.sv.tag and Splitter.TAG_LEN or 0)) .. (sent and "  -  sent" or ""))
		c.preview:SetText(previewParts[previewIndex])
		c.preview:SetTopLineIndex(1)
	else
		c.previewTitle:SetText(L("PREVIEW_HELP"))
		c.preview:SetText("")
	end
	c.previewPrev:SetEnabled(total > 0 and previewIndex > 1)
	c.previewNext:SetEnabled(total > 0 and previewIndex < total)
end

local function updateStats()
	if previewError then
		c.stats:SetText(plain(L("STATS_ERROR", previewError)))
		setColor(c.stats, COLOR_WARN)
	elseif previewParts and previewInfo then
		c.stats:SetText(L("STATS", fmt(previewInfo.chars), fmt(previewInfo.total), previewInfo.longest, previewInfo.limit))
		setColor(c.stats, previewInfo.longest >= previewInfo.limit and COLOR_HEAD or COLOR_DIM)
	else
		c.stats:SetText(L("STATS_EMPTY"))
		setColor(c.stats, COLOR_DIM)
	end
end

local function runAnalysis()
	if not initialized then return end
	local text = c.composer:GetText()
	c.placeholder:SetHidden(text ~= "")
	if text:match("^%s*$") then
		previewParts, previewInfo, previewError = nil, nil, nil
	else
		local parts, info, err = analyze(text)
		previewParts, previewInfo, previewError = parts, info, err
	end
	updateStats()
	showPreview()
	UI.Refresh()
end

-- Re-split a moment after typing stops.
local function scheduleAnalysis()
	analyzeToken = analyzeToken + 1
	local token = analyzeToken
	zo_callLater(function() if token == analyzeToken then runAnalysis() end end, 250)
end

--===============================================================================================================
-- DESTINATION
--===============================================================================================================
local function rebuildDestinations()
	local previous = destList[destIndex] and destList[destIndex].channel
	destList = {}
	c.destination:ClearItems()
	for _, destination in ipairs(Chat.Destinations) do
		-- offer only the places the player can write to right now (a guild they are not in is left out)
		local ok = Chat.Validate(destination.channel, "x")
		if ok then
			local entry = { label = destination.label, channel = destination.channel, guildIndex = destination.guildIndex }
			if destination.guildIndex then
				local nameOk, guildName = pcall(function() return GetGuildName(GetGuildId(destination.guildIndex)) end)
				if nameOk and type(guildName) == "string" and guildName ~= "" then entry.label = destination.label .. "  -  " .. plain(guildName) end
			end
			destList[#destList + 1] = entry
		end
	end
	if #destList == 0 then destList[1] = { label = L("CH_SAY"), channel = CHAT_CHANNEL_SAY } end
	for index, entry in ipairs(destList) do
		local item = c.destination:CreateItemEntry(entry.label, function() destIndex = index; UI.OnDestinationChanged() end)
		c.destination:AddItem(item)
	end
	destIndex = 1
	local want = previous or (RP.sv.destination and RP.sv.destination.channel)
	for index, entry in ipairs(destList) do if entry.channel == want then destIndex = index; break end end
	c.destination:SelectItemByIndex(destIndex, true)
end

function UI.OnDestinationChanged()
	local entry = destList[destIndex]
	local whisper = entry and entry.channel == CHAT_CHANNEL_WHISPER
	whisperShown = whisper == true
	c.targetLabel:SetHidden(not whisper)
	c.target.backdrop:SetHidden(not whisper)
	c.target:SetHidden(not whisper)
	if entry then RP.sv.destination = { channel = entry.channel, target = c.target:GetText() } end
	if initialized then UI.Layout(true) end
end

local function destination()
	local entry = destList[destIndex]
	return entry and entry.channel, c.target:GetText()
end

local function useCurrentChannel()
	local channel, target = Chat.Current()
	for index, entry in ipairs(destList) do
		if entry.channel == channel then
			destIndex = index
			c.destination:SelectItemByIndex(index, true)
			if channel == CHAT_CHANNEL_WHISPER then c.target:SetText(target or "") end
			UI.OnDestinationChanged()
			return
		end
	end
end

--===============================================================================================================
-- SETTINGS
--===============================================================================================================
local function refreshToggleLabels()
	c.sentences:SetText(L(sentenceSetting and "SENTENCES_ON" or "SENTENCES_OFF"))
	c.paragraphs:SetText(L(paragraphSetting and "PARAGRAPHS_ON" or "PARAGRAPHS_OFF"))
	c.tagToggle:SetText(L(tagSetting and "TAG_ON" or "TAG_OFF"))
	c.markerMode:SetText(L(everySetting and "MODE_EVERY" or "MODE_BETWEEN"))
	c.sound:SetText(L(soundSetting and "SOUND_ON" or "SOUND_OFF"))
end

local function fillSettingFields()
	c.maxChars:SetText(RP.sv.maxChars and RP.sv.maxChars > 0 and tostring(RP.sv.maxChars) or "")
	c.prefix:SetText(RP.sv.prefix or "")
	c.suffix:SetText(RP.sv.suffix or "")
	sentenceSetting, paragraphSetting, tagSetting, soundSetting, everySetting = RP.sv.sentences, RP.sv.paragraphs, RP.sv.tag, RP.sv.sound, RP.sv.everyPart == true
	refreshToggleLabels()
end

-- Reads the fields and toggles, checks they work together (a trial split), and keeps them. Returns true or nil + reason.
local function applySettings(quiet)
	local limit, err = Chat.GetLimit()
	if not limit then if not quiet then setNotice(err) end return nil, err end
	local entered = tonumber(c.maxChars:GetText())
	local max = limit
	if c.maxChars:GetText():match("%S") then
		if not entered or entered ~= math.floor(entered) or entered < 1 or entered > limit then
			local message = L("E_MAX_RANGE", limit)
			if not quiet then setNotice(message) end
			return nil, message
		end
		max = entered
	else
		entered = 0
	end
	local trial = { maxChars = max, reserve = tagSetting and Splitter.TAG_LEN or 0, prefix = c.prefix:GetText(), suffix = c.suffix:GetText(), sentences = sentenceSetting, paragraphs = paragraphSetting, everyPart = everySetting }
	local parts, key, detail = Splitter.Split(string.rep("word ", max), trial)
	if not parts then
		local message = refusal(key, detail)
		if not quiet then setNotice(message) end
		return nil, message
	end
	RP.sv.maxChars, RP.sv.prefix, RP.sv.suffix = entered, c.prefix:GetText(), c.suffix:GetText()
	RP.sv.sentences, RP.sv.paragraphs, RP.sv.tag, RP.sv.sound, RP.sv.everyPart = sentenceSetting, paragraphSetting, tagSetting, soundSetting, everySetting
	if not quiet then setNotice(L("NOTICE_SETTINGS")) end
	runAnalysis()
	return true
end

local MARKER_PRESETS = {
	{ key = "PRESET_PLUS", prefix = "+ ", suffix = " +", every = false },
	{ key = "PRESET_NUMBERS", prefix = "({n}/{t}) ", suffix = "", every = true },
	{ key = "PRESET_QUOTES", prefix = "\"", suffix = "\"", every = true },
	{ key = "PRESET_ELLIPSIS", prefix = "... ", suffix = " ...", every = false },
	{ key = "PRESET_ARROWS", prefix = ">> ", suffix = " >>", every = false },
	{ key = "PRESET_NONE", prefix = "", suffix = "", every = false },
}

--===============================================================================================================
-- COMPOSER ACTIONS
--===============================================================================================================
local function setComposerText(text)
	c.composer:SetText(text)
	RP.sv.draft = text
	runAnalysis()
end

local function insertAtCursor(text)
	c.composer:InsertText(text)
	c.composer:TakeFocus()
end

local function doPolish()
	local text = c.composer:GetText()
	if text == "" then return end
	undoText = text
	setComposerText(Splitter.Polish(text))
	setNotice(L("NOTICE_POLISHED"))
end

local function doUndo()
	if undoText == nil then setNotice(L("NOTICE_NOTHING_TO_UNDO")); return end
	local current = c.composer:GetText()
	setComposerText(undoText)
	undoText = current
end

local function doClear()
	if c.composer:GetText() == "" then return end
	if not clearArmed then
		clearArmed = true
		c.clear:SetText(L("CLEAR_CONFIRM"))
		zo_callLater(function() clearArmed = false; if initialized then c.clear:SetText(L("CLEAR")) end end, 3000)
		return
	end
	clearArmed = false
	c.clear:SetText(L("CLEAR"))
	undoText = c.composer:GetText()
	setComposerText("")
end

--===============================================================================================================
-- SENDING
--===============================================================================================================
-- Starts (or continues) the post. Continuing uses the destination and settings the post began with and resumes at the first part not yet seen sent.
local function startSending(continue)
	blur()
	UI.ClosePopup()
	local text = c.composer:GetText()
	local progress = RP.sv.progress
	local channel, target, startAt, usedTag = nil, nil, 1, RP.sv.tag
	local parts, info
	if continue and progress and progress.text == text then
		local limit = Chat.GetLimit()
		if not limit then setNotice(L("Q_NO_LIMIT")); return end
		local max = (progress.maxChars and progress.maxChars > 0) and math.min(progress.maxChars, limit) or limit
		channel, target, usedTag = progress.channel, progress.target, progress.tag
		local result, resultInfo, detail = Splitter.Split(text, { maxChars = max, reserve = usedTag and Splitter.TAG_LEN or 0, prefix = progress.prefix, suffix = progress.suffix,
			sentences = progress.sentences, paragraphs = progress.paragraphs, everyPart = progress.everyPart })
		if not result then setNotice(refusal(resultInfo, detail)); return end
		parts, info = result, resultInfo
		startAt = math.min((progress.confirmed or 0) + 1, #parts)
		if #parts ~= progress.total then setNotice(L("CONTINUE_CHANGED", progress.total, #parts, startAt)) end
	else
		if not applySettings(false) then return end
		local err
		parts, info, err = analyze(text)
		if not parts then setNotice(err or L("E_EMPTY")); return end
		channel, target = destination()
		RP.sv.destination = { channel = channel, target = target or "" }
		usedTag = RP.sv.tag
		RP.sv.progress = { text = text, confirmed = 0, total = #parts, channel = channel, target = target, tag = RP.sv.tag, prefix = RP.sv.prefix, suffix = RP.sv.suffix,
			sentences = RP.sv.sentences, paragraphs = RP.sv.paragraphs, everyPart = RP.sv.everyPart, maxChars = (effectiveMax()) }
	end
	local chunks = {}
	for index, part in ipairs(parts) do chunks[index] = (usedTag and Splitter.TAG or "") .. part end
	previewParts, previewInfo, previewIndex = parts, info, startAt
	local ok, err = Q.Start(chunks, channel, target, startAt)
	if ok then
		setNotice(startAt > 1 and L("NOTICE_NEXT_READY", startAt, #parts) or L("NOTICE_STARTED"))
		-- step aside so the chat window is visible; the floating bar takes over (its Open button brings the panel back)
		UI.Hide()
	elseif err then
		setNotice(err)
	end
	if not Q.active then RP.sv.progress = nil end
	UI.Refresh()
end

function UI.OnStaged(part, total, automatic)
	previewIndex = part
	if automatic then setNotice(L("NOTICE_NEXT_READY", part, total)) end
	showPreview()
end

function UI.OnQueueCompleted(postId, all)
	setNotice(all and L("NOTICE_DONE", #Q.chunks) or L("NOTICE_DONE_PARTIAL"))
	-- the composer empties itself after the last part, but only if it still holds the post that was sent
	-- keep the floating bar up for a few seconds so the player sees that the post is complete
	UI.lingerUntil = GetFrameTimeMilliseconds() + 6000
	zo_callLater(function() UI.Refresh() end, 6100)
	if RP.sv.clearWhenDone and initialized and c.composer:GetText() == (UI.sentText or "") and UI.sentText ~= "" then
		undoText = c.composer:GetText()
		setComposerText("")
	end
	RP.sv.progress = nil
end

--===============================================================================================================
-- REFRESH
--===============================================================================================================
local function setBarProgress(track, fill, fraction, width, visible)
	fraction = math.max(0, math.min(1, fraction or 0))
	track:SetHidden(not visible)
	fill:SetHidden((not visible) or fraction <= 0)
	if fraction > 0 then fill:SetDimensions(math.max(2, math.floor(width * fraction)), 12) end
end

-- Sets the width of both progress bars from how much of the post has been sent.
local function refreshProgress()
	local info = Q.Info()
	local fraction = info.active and info.sent / math.max(info.total, 1) or 0
	setBarProgress(c.track, c.fill, fraction, c.trackW or 738, tab == "compose")
	setBarProgress(c.barTrack, c.barFill, info.active and fraction or 1, c.barTrackW or 478, true)
end
UI.RefreshProgress = refreshProgress

function UI.Refresh()
	if not initialized then return end
	local info = Q.Info()
	local active = info.active
	-- action row: Start / Continue when idle, the queue controls while a post is running
	local progress = RP.sv.progress
	local canContinue = (not active) and progress and progress.text == c.composer:GetText() and (progress.confirmed or 0) > 0 and (progress.confirmed or 0) < (progress.total or 0)
	c.start:SetHidden(active)
	c.continue:SetHidden(active or not canContinue)
	if canContinue then c.continue:SetText(L("CONTINUE", (progress.confirmed or 0) + 1, progress.total)) end
	c.start:SetEnabled(not active and previewParts ~= nil)
	for _, name in ipairs({ "pause", "previous", "next", "cancel" }) do c[name]:SetHidden(not active) end
	c.pause:SetText(L(info.paused and "RESUME" or "PAUSE"))
	c.previous:SetEnabled(active and info.current > 1)
	c.next:SetText(L(info.current >= info.total and "FINISH" or "NEXT"))
	-- progress bar and status line
	local total = info.total
	if active then
		c.progressText:SetText(L("PROGRESS", info.current, total) .. "   " .. L("PROGRESS_SENT", info.sent) .. (info.paused and "   (" .. L("Q_PAUSED") .. ")" or ""))
		c.reason:SetText(plain(info.reason or ""))
	else
		c.progressText:SetText("")
		c.reason:SetText(plain(info.reason or L("IDLE")))
	end
	-- the floating bar is shown only while a post runs and the panel is closed
	local lingering = (not active) and UI.lingerUntil and GetFrameTimeMilliseconds() < UI.lingerUntil
	local showBar = (active or lingering) and c.main:IsHidden()
	c.bar:SetHidden(not showBar)
	if showBar then
		c.barTitle:SetText(active and L(info.paused and "BAR_TITLE_PAUSED" or "BAR_TITLE", info.current, total) or L("BAR_DONE"))
		c.barReason:SetText(plain(info.reason or ""))
		for _, name in ipairs({ "barPause", "barPrevious", "barNext" }) do c[name]:SetHidden(not active) end
		c.barPause:SetText(L(info.paused and "RESUME" or "PAUSE"))
		c.barPrevious:SetEnabled(info.current > 1)
		c.barNext:SetText(L(info.current >= total and "FINISH" or "NEXT"))
	end
	refreshProgress()
	showPreview()
	UI.RefreshSessions()
end

--===============================================================================================================
-- SESSIONS TAB
--===============================================================================================================
local function formatTime(timestamp)
	if type(timestamp) ~= "number" or timestamp < 0 or type(os) ~= "table" or type(os.date) ~= "function" then return L("UNKNOWN_TIME") end
	local ok, text = pcall(os.date, "%Y-%m-%d %H:%M:%S", timestamp)
	if ok and type(text) == "string" and text ~= "" then return text end
	return L("UNKNOWN_TIME")
end

local function senderName(message)
	local name = message.sender
	if type(name) ~= "string" or name == "" then name = message.displayName end
	if type(name) ~= "string" or name == "" then return L("UNKNOWN_SENDER") end
	if name:sub(1, 1) ~= "@" and type(zo_strformat) == "function" then
		local ok, formatted = pcall(zo_strformat, "<<1>>", name)
		if ok and type(formatted) == "string" and formatted ~= "" then return formatted end
	end
	return name
end

local function refreshHistory(session)
	local messages = session and session.messages or {}
	local newestFirst = RP.sv.historyNewestFirst == true
	local newest = messages[#messages]
	local orderChanged = newestFirst ~= historyNewestFirst
	c.historyOrder:SetText(L(newestFirst and "HISTORY_NEWEST" or "HISTORY_OLDEST"))
	local follow = (newest ~= historyNewest) or orderChanged
	local pages = math.max(1, math.ceil(#messages / HISTORY_PAGE_SIZE))
	if follow then historyPage = newestFirst and 1 or pages end
	historyPage = math.max(1, math.min(historyPage, pages))
	c.historyTitle:SetText(L("HISTORY_TITLE", historyPage, pages, #messages, session and session.dropped or 0))
	c.historyPrev:SetEnabled(historyPage > 1)
	c.historyNext:SetEnabled(historyPage < pages)
	local key = table.concat({ session and session.id or 0, historyPage, session and session.dropped or 0, #messages, tostring(newestFirst) }, ":")
	if not follow and historyKey == key then return end
	local first, last, step = (historyPage - 1) * HISTORY_PAGE_SIZE + 1, math.min(#messages, historyPage * HISTORY_PAGE_SIZE), 1
	if newestFirst then
		first = #messages - (historyPage - 1) * HISTORY_PAGE_SIZE
		last, step = math.max(1, first - HISTORY_PAGE_SIZE + 1), -1
	end
	local lines = {}
	for i = first, last, step do
		local message = messages[i]
		if message then
			lines[#lines + 1] = message.outgoing and L("HISTORY_OUT", formatTime(message.timestamp), message.text or "")
				or L("HISTORY_IN", formatTime(message.timestamp), senderName(message), message.text or "")
		end
	end
	c.history:SetText(table.concat(lines, "\n"))
	c.history:SetTopLineIndex(1)
	historyKey, historyNewest, historyNewestFirst = key, newest, newestFirst
end

function UI.RefreshSessions()
	if not initialized or not c.sessionCombo then return end
	local session = RP.Sessions.Current()
	local list = RP.Sessions.List()
	local id = session and session.id
	if sessionSelectedId ~= id then
		sessionSelectedId = id
		deleteArmed = false
		historyKey = nil
		loadingParticipants = true
		c.participants:SetText(session and table.concat(session.participants, "\n") or "")
		loadingParticipants = false
		participantDraft = nil
	end
	local index = 0
	for i, entry in ipairs(list) do if entry.id == id then index = i; break end end
	c.sessionInfo:SetText(session and (L("SESSION_TITLE", plain(session.name), index, #list) .. "     " .. L("SESSION_INFO", formatTime(session.createdAt))) or L("NO_SESSION"))
	local dirty = session and participantDraft ~= nil and participantDraft ~= table.concat(session.participants, "\n")
	c.participantsLabel:SetText(L(dirty and "PARTICIPANTS_DIRTY" or "PARTICIPANTS"))
	local on = session ~= nil
	c.saveParticipants:SetEnabled(on)
	c.record:SetEnabled(on)
	c.delete:SetEnabled(on)
	c.addonOnly:SetEnabled(on)
	local recording = RP.Sessions.IsRecording()
	c.record:SetText(L(recording and "RECORD_STOP" or "RECORD_START"))
	c.addonOnly:SetText(L(session and session.addonOnly and "ADDON_ONLY_ON" or "ADDON_ONLY_OFF"))
	c.delete:SetText(L(deleteArmed and "DELETE_CONFIRM" or "DELETE_SESSION"))
	c.recordWarning:SetText(L(recording and "RECORD_WARNING_ON" or "RECORD_WARNING_OFF"))
	refreshHistory(session)
	if tab == "sessions" then UI.Layout(true) end
end

local function rebuildSessionCombo()
	c.sessionCombo:ClearItems()
	local current = RP.Sessions.Current()
	local selectedIndex
	for index, session in ipairs(RP.Sessions.List()) do
		local item = c.sessionCombo:CreateItemEntry(plain(session.name), function()
			RP.Sessions.Select(session.id)
			UI.RefreshSessions()
		end)
		c.sessionCombo:AddItem(item)
		if current and current.id == session.id then selectedIndex = index end
	end
	if selectedIndex then c.sessionCombo:SelectItemByIndex(selectedIndex, true) else c.sessionCombo:SetSelectedItemText(L("NO_SESSION")) end
end

--===============================================================================================================
-- LIBRARY TAB
--===============================================================================================================
local function findLibrary(id)
	for index, entry in ipairs(RP.sv.library) do if entry.id == id then return entry, index end end
end

local function refreshLibraryPreview()
	local entry = libSelected and findLibrary(libSelected)
	c.libPreview:SetText(entry and entry.text or "")
	c.libPreview:SetTopLineIndex(1)
	c.libLoad:SetEnabled(entry ~= nil)
	c.libInsert:SetEnabled(entry ~= nil)
	c.libDelete:SetEnabled(entry ~= nil)
	c.libDelete:SetText(L(libDeleteArmed and "LIB_DELETE_CONFIRM" or "LIB_DELETE"))
	c.libEmpty:SetHidden(#RP.sv.library > 0)
	if tab == "library" then UI.Layout(true) end
end

local function rebuildLibraryCombo()
	c.libCombo:ClearItems()
	local selectedIndex
	for index, entry in ipairs(RP.sv.library) do
		local item = c.libCombo:CreateItemEntry(plain(L("LIB_LINE", entry.name, Splitter.Length(entry.text) or 0)), function()
			libSelected = entry.id
			libDeleteArmed = false
			refreshLibraryPreview()
		end)
		c.libCombo:AddItem(item)
		if entry.id == libSelected then selectedIndex = index end
	end
	if selectedIndex then c.libCombo:SelectItemByIndex(selectedIndex, true) else c.libCombo:SetSelectedItemText(L("LIB_PICK")); libSelected = nil end
	refreshLibraryPreview()
end

--===============================================================================================================
-- LAYOUT
-- The panel can be made very small. Every element is placed from the current size. What does not fit is folded behind a small button that
-- opens it as a pop-up, and it comes back into the window by itself when there is room again. Nothing here is saved: the choice is made
-- again every time the size changes.
--===============================================================================================================
local MIN_W, MIN_H, MAX_W, MAX_H = 340, 300, 1500, 1100
local DEFAULT_W, DEFAULT_H = 780, 672
local BAR_MIN_W, BAR_MAX_W, BAR_H = 500, 900, 110	-- 500 is the width its five buttons need side by side
-- Space above and below the content: header and tabs / status and version. Narrow windows put the tab menu and the version in the header row.
local function chrome(width)
	if width >= 520 then return 92, 62 end
	return 52, 40
end
local TABS_INLINE_WIDTH = 520						-- narrower than this, the three tab buttons fold into one menu button
local layoutW, layoutH, barLayoutW = 0, 0, 0
local dry = false									-- true while only measuring: nothing is moved or shown

local function put(item, x, y, width, height)
	if dry then return end
	item:ClearAnchors()
	item:SetAnchor(TOPLEFT, item.rpParent, TOPLEFT, x, y)
	item:SetDimensions(width or item.rpW or 0, height or item.rpH or 0)
end
local function putEdit(item, x, y, width, height) put(item.backdrop, x, y, width, height) end
local function putCombo(box, x, y, width) put(box.container, x, y, width, 28) end

-- A label whose height follows its wrapped text. Returns the height.
local function putText(item, x, y, width)
	if not dry then
		item:ClearAnchors()
		item:SetAnchor(TOPLEFT, item.rpParent, TOPLEFT, x, y)
	end
	item:SetDimensions(width, 400)
	local height = math.max(item:GetTextHeight(), 20)
	item:SetDimensions(width, height)
	return height
end

-- Places items left to right and starts a new row when the next one does not fit. item = { w, h, fn(x, y, w) }. Returns the y under the last row.
local FLOW_SLACK = 24	-- spare pixels a row must have left before another item joins it, so wider text in another language wraps instead of overlapping
local function flow(items, y, rowWidth, gap, rowGap)
	local x, rowHeight = 0, 0
	for _, item in ipairs(items) do
		local width = math.min(item.w, rowWidth)
		if x > 0 and x + width > rowWidth - FLOW_SLACK then x = 0; y = y + rowHeight + rowGap; rowHeight = 0 end
		item.fn(x, y, width)
		x = x + width + gap
		rowHeight = math.max(rowHeight, item.h)
	end
	return y + rowHeight
end
local function btn(item, width, height) return { w = width, h = height or item.rpH, fn = function(x, y, w) put(item, x, y, w, height or item.rpH) end } end

--===============================================================================================================
-- PIECES THAT CAN MOVE BETWEEN THE WINDOW AND A POP-UP
--===============================================================================================================
local measureWhisper = false	-- true while measuring the smallest size, so the wider whisper row is counted

local function placeTools(cw, y, inline)
	local tools = {}
	for _, item in ipairs(c.inserts) do tools[#tools + 1] = btn(item, 30, 26) end
	tools[#tools + 1] = btn(c.polish, 76, 26); tools[#tools + 1] = btn(c.undo, 64, 26); tools[#tools + 1] = btn(c.clear, 96, 26)
	if inline then tools[#tools + 1] = btn(c.composeSave, 76, 26) end
	local toolsEnd = flow(tools, y, cw, 4, 4)
	if inline and cw >= 492 + 8 + 240 then
		c.stats:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
		put(c.stats, 500, y + 2, cw - 500, 22)
	else
		c.stats:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		put(c.stats, 0, toolsEnd + 4, cw, 22)
		toolsEnd = toolsEnd + 4 + 22
	end
	return toolsEnd
end

local function placeOptions(cw, y)
	local fieldGroup = function(lab, width, putWidget) return { w = width, h = 48, fn = function(x, yy) put(lab, x, yy, width, 20); putWidget(x, yy + 20, width) end } end
	local settings = {
		fieldGroup(c.lblMax, 90, function(x, yy, w) putEdit(c.maxChars, x, yy, w, 28) end),
		fieldGroup(c.lblPrefix, 110, function(x, yy, w) putEdit(c.prefix, x, yy, w, 28) end),
		fieldGroup(c.lblSuffix, 110, function(x, yy, w) putEdit(c.suffix, x, yy, w, 28) end),
		fieldGroup(c.lblMarkers, 190, function(x, yy, w) putCombo(c.markers, x, yy, w) end),
		{ w = 100, h = 48, fn = function(x, yy) put(c.apply, x, yy + 20, 100, 28) end },
	}
	y = flow(settings, y, cw, 10, 6) + 8
	return flow({ btn(c.sentences, 176, 28), btn(c.paragraphs, 184, 28), btn(c.tagToggle, 140, 28), btn(c.sound, 120, 28), btn(c.markerMode, 190, 28) }, y, cw, 10, 6) + 10
end

local function placePreview(cw, y, height)
	put(c.previewTitle, 0, y + 2, math.max(60, cw - 120), 22)
	put(c.previewPrev, cw - 110, y, 50, 26)
	put(c.previewNext, cw - 50, y, 50, 26)
	y = y + 30
	putEdit(c.preview, 0, y, cw, height)
	return y + height + 8
end

--===============================================================================================================
-- POP-UPS
--===============================================================================================================
local popups = {}
UI.popups = popups
local openPopupId

local function adopt(item, parent) if item.rpParent ~= parent then item:SetParent(parent); item.rpParent = parent end end
local function adoptAll(list, parent) for _, item in ipairs(list) do adopt(item, parent) end end

-- id -> where the pieces live, what they are called, how wide the pop-up is, and how they are arranged inside it (returns the height used)
local POPUP_DEFS = {
	tools = { tab = "compose", width = 340, title = "POP_TOOLS", home = function() return c.compose end, controls = function() return c.toolControls end,
		place = function(bw)
			local y = placeTools(bw, 0, false) + 8
			return flow({ btn(c.useCurrent, math.min(204, bw), 28) }, y, bw, 10, 6)
		end },
	options = { tab = "compose", width = 420, title = "POP_OPTIONS", home = function() return c.compose end, controls = function() return c.optionControls end,
		place = function(bw) return placeOptions(bw, 0) end },
	preview = { tab = "compose", width = 420, title = "POP_PREVIEW", home = function() return c.compose end, controls = function() return c.previewControls end,
		place = function(bw) return placePreview(bw, 0, 150) end },
	quicksave = { tab = "compose", width = 340, title = "POP_SAVE", home = function() return c.compose end,
		controls = function() return { c.qsLabel, c.qsName.backdrop, c.qsSave } end,
		place = function(bw)
			put(c.qsLabel, 0, 0, bw, 22)
			putEdit(c.qsName, 0, 24, bw, 28)
			return flow({ btn(c.qsSave, math.min(200, bw), 28) }, 60, bw, 10, 6)
		end },
	session = { tab = "sessions", width = 360, title = "POP_SESSION", home = function() return c.sessions end,
		controls = function() return { c.sessionName.backdrop, c.createSession, c.delete } end,
		place = function(bw)
			putEdit(c.sessionName, 0, 0, bw, 28)
			return flow({ btn(c.createSession, 170, 28), btn(c.delete, 150, 28) }, 36, bw, 10, 6)
		end },
	people = { tab = "sessions", width = 380, title = "POP_PEOPLE", home = function() return c.sessions end,
		controls = function() return { c.participantsLabel, c.participants.backdrop, c.saveParticipants } end,
		place = function(bw)
			local y = putText(c.participantsLabel, 0, 0, bw) + 4
			putEdit(c.participants, 0, y, bw, 90)
			return flow({ btn(c.saveParticipants, 160, 28) }, y + 98, bw, 10, 6)
		end },
	recording = { tab = "sessions", width = 380, title = "POP_RECORDING", home = function() return c.sessions end,
		controls = function() return { c.addonOnly, c.recordWarning } end,
		place = function(bw)
			local y = flow({ btn(c.addonOnly, math.min(220, bw), 28) }, 0, bw, 10, 6) + 8
			return y + putText(c.recordWarning, 0, y, bw)
		end },
	libsave = { tab = "library", width = 380, title = "POP_SAVE", home = function() return c.library end,
		controls = function() return { c.libHelp, c.libNameLabel, c.libName.backdrop, c.libSave } end,
		place = function(bw)
			local y = putText(c.libHelp, 0, 0, bw) + 8
			put(c.libNameLabel, 0, y, bw, 22)
			putEdit(c.libName, 0, y + 24, bw, 28)
			return flow({ btn(c.libSave, math.min(200, bw), 28) }, y + 60, bw, 10, 6)
		end },
	tabs = { tab = "any", width = 200, title = "TITLE", home = function() return c.main end,
		controls = function() return { c.tabCompose, c.tabSessions, c.tabLibrary } end,
		place = function(bw)
			put(c.tabCompose, 0, 0, bw, 28); put(c.tabSessions, 0, 34, bw, 28); put(c.tabLibrary, 0, 68, bw, 28)
			return 96
		end },
}

local function getPopup(id)
	local pop = popups[id]
	if pop then return pop end
	local def = POPUP_DEFS[id]
	local frame = WINDOW_MANAGER:CreateTopLevelWindow("tomRoleplayPopup" .. id)
	frame:SetDimensions(def.width, 120)
	frame:SetClampedToScreen(true)
	frame:SetMouseEnabled(true)
	frame:SetDrawTier(DT_MEDIUM)	-- above the panel, below the drop-down lists of combo boxes
	frame:SetHidden(true)
	local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(controlName(), frame, "ZO_DefaultBackdrop")
	backdrop:SetAnchorFill(frame)
	local title = label(frame, "", 10, 8, def.width - 60, 22, "ZoFontGameBold", COLOR_HEAD)
	local close = button(frame, "x", def.width - 38, 4, 30, function() UI.ClosePopup() end, 26)
	local body = makeControl(frame, CT_CONTROL, 10, 34, def.width - 20, 80)
	pop = { id = id, def = def, frame = frame, title = title, close = close, body = body }
	popups[id] = pop
	return pop
end

function UI.ClosePopup()
	if openPopupId then
		local pop = popups[openPopupId]
		if pop then pop.frame:SetHidden(true) end
		openPopupId = nil
	end
end

-- Arranges the pop-up's contents and puts it under its button.
function UI.PlacePopup(id)
	local pop = getPopup(id)
	local bw = pop.def.width - 20
	local height = pop.def.place(bw)
	pop.body:SetDimensions(bw, height)
	pop.frame:SetDimensions(pop.def.width, height + 44)
	pop.title:SetText((L(pop.def.title):gsub("%.%.%.$", "")))
	pop.frame:ClearAnchors()
	local anchor = c.popBtn[id]
	if id == "quicksave" then anchor = c.composeSave end
	pop.frame:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, 0, 4)
	pop.frame:SetHidden(false)
end

function UI.TogglePopup(id)
	if openPopupId == id then UI.ClosePopup(); return end
	UI.ClosePopup()
	openPopupId = id
	UI.PlacePopup(id)
end

-- Moves a group of controls into its pop-up (folded) or back into the window, and shows or hides the button that opens it.
local function foldGroup(id, folded)
	local def = POPUP_DEFS[id]
	adoptAll(def.controls(), folded and getPopup(id).body or def.home())
	c.popBtn[id]:SetHidden(not folded)
	if not folded and openPopupId == id then UI.ClosePopup() end
end

--===============================================================================================================
-- COMPOSE TAB
--===============================================================================================================
-- inl says which groups are placed in the window; the others are behind their buttons. Returns the height used.
local function composeRows(cw, composerH, previewH, inl)
	local whisper = measureWhisper or whisperShown
	local row = { { w = 224, h = 28, fn = function(x, y) put(c.toLabel, x, y + 3, 32, 22); putCombo(c.destination, x + 34, y, 190) end } }
	if whisper then row[#row + 1] = { w = 290, h = 28, fn = function(x, y, w) put(c.targetLabel, x, y + 3, 88, 22); putEdit(c.target, x + 90, y, w - 90, 28) end } end
	if inl.tools then row[#row + 1] = btn(c.useCurrent, 204, 28) end
	local y = flow(row, 0, cw, 10, 8) + 8
	putEdit(c.composer, 0, y, cw, composerH)
	put(c.placeholder, 8, y + 8, math.max(40, cw - 16), 22)
	y = y + composerH + 6
	if inl.tools then y = placeTools(cw, y, true) + 8 end
	local folded = {}
	if not inl.tools then folded[#folded + 1] = btn(c.composeSave, 76, 26); folded[#folded + 1] = btn(c.popBtn.tools, 88, 26) end
	if not inl.options then folded[#folded + 1] = btn(c.popBtn.options, 88, 26) end
	if not inl.preview then folded[#folded + 1] = btn(c.popBtn.preview, 88, 26) end
	if #folded > 0 then y = flow(folded, y, cw, 6, 6) + 8 end
	if inl.options then y = placeOptions(cw, y) end
	if inl.preview then y = placePreview(cw, y, previewH) end
	-- Start / Continue while idle, the queue buttons while a post runs: both sets are measured so the row keeps its height
	local idle, running
	if inl.tight then	-- smallest window: shorter buttons so each set fits one row
		idle = { btn(c.start, 96, 26), btn(c['continue'], math.min(168, cw - 104), 26) }
		running = { btn(c.pause, 66, 26), btn(c.previous, 66, 26), btn(c.next, 66, 26), btn(c.cancel, 66, 26) }
		y = math.max(flow(idle, y, cw, 4, 4), flow(running, y, cw, 4, 4)) + 6
	else
		idle = { btn(c.start, math.min(200, cw), 32), btn(c['continue'], math.min(250, cw), 32) }
		running = { btn(c.pause, 100, 32), btn(c.previous, 100, 32), btn(c.next, 100, 32), btn(c.cancel, 100, 32) }
		y = math.max(flow(idle, y, cw, 8, 6), flow(running, y, cw, 8, 6)) + 10
	end
	if not dry then
		c.track:ClearAnchors(); c.track:SetAnchor(TOPLEFT, c.compose, TOPLEFT, 0, y); c.track:SetDimensions(cw, 14)
		c.fill:ClearAnchors(); c.fill:SetAnchor(TOPLEFT, c.compose, TOPLEFT, 1, y + 1)
		c.trackW = cw - 2
	end
	y = y + 18
	put(c.progressText, 0, y, cw, 20)
	y = y + 20
	return y + putText(c.reason, 0, y, cw)
end

local COMPOSER_MIN, PREVIEW_MIN = 60, 44
local COMPOSE_STAGES = {
	{ tools = true, options = true, preview = true },
	{ tools = true, options = true, preview = false },
	{ tools = true, options = false, preview = false },
	{ tools = false, options = false, preview = false },
	{ tools = false, options = false, preview = false, tight = true },
}
local function measure(fn, ...) dry = true; local used = fn(...); dry = false; return used end

local function layoutCompose(cw, ch)
	local inl = COMPOSE_STAGES[#COMPOSE_STAGES]
	for _, stage in ipairs(COMPOSE_STAGES) do
		if measure(composeRows, cw, COMPOSER_MIN, PREVIEW_MIN, stage) <= ch then inl = stage; break end
	end
	local used = measure(composeRows, cw, COMPOSER_MIN, PREVIEW_MIN, inl)
	foldGroup("tools", not inl.tools); foldGroup("options", not inl.options); foldGroup("preview", not inl.preview)
	local extra = math.max(0, ch - used)
	local composerExtra = inl.preview and math.floor(extra * 0.62) or extra
	composeRows(cw, COMPOSER_MIN + composerExtra, PREVIEW_MIN + (extra - composerExtra), inl)
	return used
end

--===============================================================================================================
-- SESSIONS TAB
--===============================================================================================================
local HISTORY_MIN = 40
local SESSION_STAGES = {
	{ create = true, people = true, recording = true },
	{ create = true, people = true, recording = false },
	{ create = true, people = false, recording = false },
	{ create = false, people = false, recording = false },
}
local function sessionsRows(cw, historyH, inl)
	local row = { { w = math.min(300, cw), h = 28, fn = function(x, y, w) putCombo(c.sessionCombo, x, y, w) end } }
	if inl.create then
		row[#row + 1] = { w = 200, h = 28, fn = function(x, y, w) putEdit(c.sessionName, x, y, w, 28) end }
		row[#row + 1] = btn(c.createSession, 160, 28)
		row[#row + 1] = btn(c.delete, 130, 28)
	end
	local y = flow(row, 0, cw, 10, 6) + 6
	y = y + putText(c.sessionInfo, 0, y, cw) + 6
	if inl.people then
		y = y + putText(c.participantsLabel, 0, y, cw) + 4
		putEdit(c.participants, 0, y, cw, 56)
		y = y + 62
	end
	local buttons = {}
	if inl.people then buttons[#buttons + 1] = btn(c.saveParticipants, 150, 28) end
	buttons[#buttons + 1] = btn(c.record, 190, 28)
	if inl.recording then buttons[#buttons + 1] = btn(c.addonOnly, 200, 28) end
	if not inl.create then buttons[#buttons + 1] = btn(c.popBtn.session, 88, 26) end
	if not inl.people then buttons[#buttons + 1] = btn(c.popBtn.people, 88, 26) end
	if not inl.recording then buttons[#buttons + 1] = btn(c.popBtn.recording, 88, 26) end
	y = flow(buttons, y, cw, 8, 6) + 6
	if inl.recording then y = y + putText(c.recordWarning, 0, y, cw) + 6 end
	y = flow({
		{ w = 220, h = 26, fn = function(x, yy, w) put(c.historyTitle, x, yy + 4, w, 22) end },
		btn(c.historyOrder, 140, 26), btn(c.historyPrev, 46, 26), btn(c.historyNext, 46, 26),
	}, y, cw, 6, 4) + 6
	putEdit(c.history, 0, y, cw, historyH)
	put(c.selectAll, 0, y + historyH + 6, 150, 26)
	return y + historyH + 6 + 26
end

local function layoutSessions(cw, ch)
	local inl = SESSION_STAGES[#SESSION_STAGES]
	for _, stage in ipairs(SESSION_STAGES) do
		if measure(sessionsRows, cw, HISTORY_MIN, stage) <= ch then inl = stage; break end
	end
	local used = measure(sessionsRows, cw, HISTORY_MIN, inl)
	foldGroup("session", not inl.create); foldGroup("people", not inl.people); foldGroup("recording", not inl.recording)
	sessionsRows(cw, HISTORY_MIN + math.max(0, ch - used), inl)
	return used
end

--===============================================================================================================
-- LIBRARY TAB
--===============================================================================================================
local LIB_PREVIEW_MIN = 40
local LIB_STAGES = { { save = true }, { save = false } }
local function libraryRows(cw, previewH, inl)
	local y = 0
	if inl.save then
		y = putText(c.libHelp, 0, 0, cw) + 8
		local nameWidth = cw >= 520 and (cw - 70 - 180 - 12) or 200
		y = flow({ { w = 70, h = 28, fn = function(x, yy) put(c.libNameLabel, x, yy + 4, 70, 22) end },
			{ w = nameWidth, h = 28, fn = function(x, yy, w) putEdit(c.libName, x, yy, w, 28) end }, btn(c.libSave, 180, 28) }, y, cw, 6, 6) + 8
	end
	putCombo(c.libCombo, 0, y, cw)
	y = y + 36
	local buttons = { btn(c.libLoad, 140, 28), btn(c.libInsert, 170, 28), btn(c.libDelete, 120, 28) }
	if not inl.save then buttons[#buttons + 1] = btn(c.popBtn.libsave, 88, 26) end
	y = flow(buttons, y, cw, 8, 6) + 8
	if not c.libEmpty:IsHidden() then y = y + putText(c.libEmpty, 0, y, cw) + 8 end
	putEdit(c.libPreview, 0, y, cw, previewH)
	return y + previewH
end

local function layoutLibrary(cw, ch)
	local inl = LIB_STAGES[#LIB_STAGES]
	for _, stage in ipairs(LIB_STAGES) do
		if measure(libraryRows, cw, LIB_PREVIEW_MIN, stage) <= ch then inl = stage; break end
	end
	local used = measure(libraryRows, cw, LIB_PREVIEW_MIN, inl)
	foldGroup("libsave", not inl.save)
	libraryRows(cw, LIB_PREVIEW_MIN + math.max(0, ch - used), inl)
	return used
end

--===============================================================================================================
-- THE WHOLE PANEL
--===============================================================================================================
-- Places the whole panel from its current size. force = false skips the work while the size has not changed (used while dragging).
function UI.Layout(force)
	if not initialized then return end
	local width, height = c.main:GetWidth(), c.main:GetHeight()
	if not force and width == layoutW and height == layoutH then return end
	layoutW, layoutH = width, height
	local chromeTop, chromeBottom = chrome(width)
	local cw, ch = width - 40, height - chromeTop - chromeBottom
	put(c.closeButton, width - 40, 6, 30, 30)
	put(c.help, width - 74, 8, 26, 26)
	put(c.line, 10, 42, width - 20, 2)
	c.title:SetHidden(width < TABS_INLINE_WIDTH)
	c.icon:SetHidden(width < TABS_INLINE_WIDTH)	-- the small header holds the tab menu instead
	put(c.tomBubble, width < TABS_INLINE_WIDTH and 8 or 44, width < TABS_INLINE_WIDTH and 7 or 6, 30, 30)
	-- the tab buttons sit in the window when it is wide, in a pop-up behind one menu button when it is narrow
	local wide = width >= TABS_INLINE_WIDTH
	foldGroup("tabs", not wide)
	if wide then
		put(c.tabCompose, 20, 52, 140, 28); put(c.tabSessions, 170, 52, 140, 28); put(c.tabLibrary, 320, 52, 140, 28)
	else
		put(c.tabMenu, 42, 8, 150, 28)
	end
	put(c.compose, 20, chromeTop, cw, ch); put(c.sessions, 20, chromeTop, cw, ch); put(c.library, 20, chromeTop, cw, ch)
	put(c.status, 20, height - chromeBottom + 4, cw, 34)
	c.version:SetHorizontalAlignment(wide and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
	if wide then put(c.version, 20, height - 22, cw, 16) else put(c.version, 198, 14, 62, 16) end
	if tab == "compose" then layoutCompose(cw, ch)
	elseif tab == "sessions" then layoutSessions(cw, ch)
	else layoutLibrary(cw, ch) end
	-- an open pop-up stays arranged and under its button
	if openPopupId then
		if POPUP_DEFS[openPopupId].tab == "any" or POPUP_DEFS[openPopupId].tab == tab then UI.PlacePopup(openPopupId) else UI.ClosePopup() end
	end
	refreshProgress()
end

-- The smallest height at which every tab still fits at a given width, with everything that can fold behind a button folded. Used for the resize limit.
function UI.Chrome(width) return chrome(width) end

function UI.MinimumHeight(width)
	local cw = width - 40
	measureWhisper = true
	local needed = math.max(
		measure(composeRows, cw, COMPOSER_MIN, PREVIEW_MIN, COMPOSE_STAGES[#COMPOSE_STAGES]),
		measure(sessionsRows, cw, HISTORY_MIN, SESSION_STAGES[#SESSION_STAGES]),
		measure(libraryRows, cw, LIB_PREVIEW_MIN, LIB_STAGES[#LIB_STAGES]))
	measureWhisper = false
	local top, bottom = chrome(width)
	return needed + top + bottom + 24	-- a little spare for a longer line of text
end

-- Sets the smallest and largest size the player can drag the panel to.
function UI.UpdateLimits()
	c.main:SetDimensionConstraints(MIN_W, math.max(MIN_H, UI.MinimumHeight(MIN_W)), MAX_W, MAX_H)
end

-- The floating bar only changes width.
function UI.LayoutBar(force)
	if not initialized then return end
	local width = c.bar:GetWidth()
	if not force and width == barLayoutW then return end
	barLayoutW = width
	put(c.barTitle, 14, 8, width - 28, 22)
	put(c.barReason, 14, 30, width - 28, 20)
	c.barTrack:ClearAnchors(); c.barTrack:SetAnchor(TOPLEFT, c.bar, TOPLEFT, 10, 54); c.barTrack:SetDimensions(width - 20, 14)
	c.barFill:ClearAnchors(); c.barFill:SetAnchor(TOPLEFT, c.bar, TOPLEFT, 11, 55)
	c.barTrackW = width - 22
	put(c.barPause, 10, 76, 100, 26); put(c.barPrevious, 116, 76, 100, 26); put(c.barNext, 222, 76, 100, 26)
	put(c.barCancel, 328, 76, 80, 26); put(c.barOpen, width - 86, 76, 76, 26)
	refreshProgress()
end

-- Resize handles: the layout follows the mouse while a window is being dragged, then the size is remembered.
local function enableResize()
	c.main:SetResizeHandleSize(6)
	UI.UpdateLimits()
	c.main:SetHandler("OnResizeStart", function(self) self:SetHandler("OnUpdate", function() UI.Layout(false) end) end)
	c.main:SetHandler("OnResizeStop", function(self)
		self:SetHandler("OnUpdate", nil)
		UI.Layout(true)
		RP.sv.size = { width = self:GetWidth(), height = self:GetHeight() }
		tomUI.roleplayMoveStop(self)
	end)
	c.bar:SetResizeHandleSize(6)
	c.bar:SetDimensionConstraints(BAR_MIN_W, BAR_H, BAR_MAX_W, BAR_H)
	c.bar:SetHandler("OnResizeStart", function(self) self:SetHandler("OnUpdate", function() UI.LayoutBar(false) end) end)
	c.bar:SetHandler("OnResizeStop", function(self)
		self:SetHandler("OnUpdate", nil)
		UI.LayoutBar(true)
		RP.sv.barWidth = self:GetWidth()
		tomUI.roleplayBarMoveStop(self)
	end)
end

local function popButton(id, parent, key)
	local b = button(parent, L(key), 0, 0, 88, function() UI.TogglePopup(id) end, 26)
	b:SetHidden(true)
	c.popBtn[id] = b
end

local function changeTab(name)
	blur()
	UI.ClosePopup()
	tab = name
	c.tabMenu:SetText(L(name == "compose" and "TAB_COMPOSE" or name == "sessions" and "TAB_SESSIONS" or "TAB_LIBRARY") .. "...")
	clearArmed, deleteArmed, libDeleteArmed = false, false, false
	c.compose:SetHidden(name ~= "compose")
	c.sessions:SetHidden(name ~= "sessions")
	c.library:SetHidden(name ~= "library")
	c.tabCompose:SetEnabled(name ~= "compose")
	c.tabSessions:SetEnabled(name ~= "sessions")
	c.tabLibrary:SetEnabled(name ~= "library")
	if name == "sessions" then rebuildSessionCombo(); UI.RefreshSessions()
	elseif name == "library" then rebuildLibraryCombo() end
	UI.Layout(true)
	refreshProgress()
end

local function buildCompose()
	local p = c.compose
	c.toLabel = label(p, L("TO"), 0, 3, 32)
	c.destination = combo(p, 34, 0, 190)
	c.targetLabel = label(p, L("WHISPER_TO"), 236, 3, 88)
	c.target = edit(p, 326, 0, 200, 28, false)
	c.useCurrent = button(p, L("USE_CURRENT"), 536, 0, 204, useCurrentChannel)
	tip(c.useCurrent, L("USE_CURRENT_TIP"))

	c.composer = edit(p, 0, 36, 740, 170, true)
	c.placeholder = label(p, L("PLACEHOLDER"), 8, 44, 700, 22, "ZoFontGame", COLOR_DIM)
	c.placeholder:SetMouseEnabled(false)
	c.composer:SetHandler("OnTextChanged", function(self)
		RP.sv.draft = self:GetText()
		-- editing the text of an interrupted post means it is no longer that post
		if RP.sv.progress and RP.sv.progress.text ~= self:GetText() and not Q.active then RP.sv.progress = nil end
		c.placeholder:SetHidden(self:GetText() ~= "")
		scheduleAnalysis()
	end)

	-- quick-insert buttons keep the cursor in the text
	local inserts = { { "\226\128\156", "“" }, { "\226\128\157", "”" }, { "\226\128\166", "…" }, { "\226\128\148", "—" }, { "*", "*" } }
	local x = 0
	c.inserts = {}
	for _, entry in ipairs(inserts) do
		local b = button(p, entry[2], x, 212, 30, function() insertAtCursor(entry[1]) end, 26)
		c.inserts[#c.inserts + 1] = b
		ZO_PreHookHandler(b, "OnMouseDown", function() IgnoreMouseDownEditFocusLoss() end)
		tip(b, L("INSERT_TIP"))
		x = x + 32
	end
	c.polish = button(p, L("POLISH"), 168, 212, 76, doPolish, 26)
	tip(c.polish, L("POLISH_TIP"))
	c.undo = button(p, L("UNDO"), 248, 212, 64, doUndo, 26)
	c.clear = button(p, L("CLEAR"), 316, 212, 96, doClear, 26)
	tip(c.clear, L("CLEAR_TIP"))
	-- Save...: asks for a name, then stores the composed text in the library
	c.composeSave = button(p, L("POP_SAVE"), 416, 212, 76, function()
		UI.TogglePopup("quicksave")
		if openPopupId == "quicksave" then c.qsName:TakeFocus() end
	end, 26)
	tip(c.composeSave, L("QUICKSAVE_TIP"))
	local qsBody = getPopup("quicksave").body
	c.qsLabel = label(qsBody, L("QUICKSAVE_PROMPT"), 0, 0, 300, 22, "ZoFontGame", COLOR_HEAD)
	c.qsName = edit(qsBody, 0, 24, 300, 28, false, 60)
	c.qsSave = button(qsBody, L("LIB_SAVE"), 0, 60, 200, function()
		if UI.SaveToLibrary(c.qsName:GetText()) then c.qsName:SetText(""); UI.ClosePopup() end
	end, 28)
	c.stats = label(p, "", 420, 214, 320, 22, "ZoFontGameSmall", COLOR_DIM)
	c.stats:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

	-- settings
	c.lblMax = label(p, L("MAX_CHARS"), 0, 246, 90, 20, "ZoFontGameSmall", COLOR_HEAD)
	c.lblPrefix = label(p, L("PREFIX"), 100, 246, 110, 20, "ZoFontGameSmall", COLOR_HEAD)
	c.lblSuffix = label(p, L("SUFFIX"), 220, 246, 110, 20, "ZoFontGameSmall", COLOR_HEAD)
	c.lblMarkers = label(p, L("MARKERS"), 340, 246, 100, 20, "ZoFontGameSmall", COLOR_HEAD)
	c.maxChars = edit(p, 0, 266, 90, 28, false, 5)
	c.prefix = edit(p, 100, 266, 110, 28, false, 24)
	c.suffix = edit(p, 220, 266, 110, 28, false, 24)
	for _, field in ipairs({ c.maxChars, c.prefix, c.suffix }) do
		field:SetHandler("OnFocusLost", function() applySettings(true) end)
		field:SetHandler("OnEnter", function() applySettings(false); blur() end)
	end
	c.markers = combo(p, 340, 266, 190)
	for _, preset in ipairs(MARKER_PRESETS) do
		local item = c.markers:CreateItemEntry(L(preset.key), function()
			c.prefix:SetText(preset.prefix)
			c.suffix:SetText(preset.suffix)
			everySetting = preset.every
			refreshToggleLabels()
			applySettings(false)
		end)
		c.markers:AddItem(item)
	end
	c.markers:SetSelectedItemText(L("MARKERS"))
	tip(c.markers.container, L("MARKERS_TIP"))
	c.apply = button(p, L("APPLY"), 540, 266, 100, function() applySettings(false) end)

	c.sentences = button(p, "", 0, 300, 180, function() sentenceSetting = not sentenceSetting; refreshToggleLabels(); applySettings(true) end)
	tip(c.sentences, L("SENTENCES_TIP"))
	c.paragraphs = button(p, "", 190, 300, 180, function() paragraphSetting = not paragraphSetting; refreshToggleLabels(); applySettings(true) end)
	tip(c.paragraphs, L("PARAGRAPHS_TIP"))
	c.tagToggle = button(p, "", 380, 300, 170, function() tagSetting = not tagSetting; refreshToggleLabels(); applySettings(true) end)
	tip(c.tagToggle, L("TAG_TIP"))
	c.markerMode = button(p, "", 0, 332, 190, function() everySetting = not everySetting; refreshToggleLabels(); applySettings(true) end)
	tip(c.markerMode, L("MODE_TIP"))
	c.sound = button(p, "", 560, 300, 180, function() soundSetting = not soundSetting; refreshToggleLabels(); applySettings(true) end)
	tip(c.sound, L("SOUND_TIP"))

	-- preview of the parts
	c.previewTitle = label(p, "", 0, 338, 610, 22, "ZoFontGameBold", COLOR_HEAD)
	c.previewPrev = button(p, "<", 628, 334, 50, function() previewIndex = previewIndex - 1; showPreview() end, 26)
	c.previewNext = button(p, ">", 690, 334, 50, function() previewIndex = previewIndex + 1; showPreview() end, 26)
	c.preview = edit(p, 0, 364, 740, 56, true)

	-- action row: either Start/Continue or the queue controls
	c.start = button(p, L("START"), 0, 428, 220, function() UI.sentText = c.composer:GetText(); startSending(false) end, 32)
	c.continue = button(p, "", 232, 428, 260, function() UI.sentText = c.composer:GetText(); startSending(true) end, 32)
	tip(c.continue, L("CONTINUE_TIP"))
	c.pause = button(p, L("PAUSE"), 0, 428, 130, function()
		local ok, err
		if Q.paused then ok, err = Q.Resume() else ok, err = Q.Pause(L("Q_PAUSED")) end
		if not ok and err then setNotice(err) end
	end, 32)
	c.previous = button(p, L("PREVIOUS"), 140, 428, 120, function() setNotice(L("PREVIOUS_WARNING")); local ok, err = Q.Move(-1); if not ok and err then setNotice(err) end end, 32)
	c.next = button(p, L("NEXT"), 270, 428, 120, function() local ok, err = Q.Move(1); if not ok and err then setNotice(err) end end, 32)
	c.cancel = button(p, L("CANCEL"), 400, 428, 120, function() Q.Cancel() end, 32)

	-- progress bar (declared in tom.xml)
	c.track = tomRoleplayTrack
	c.fill = tomRoleplayFill
	c.track:ClearAnchors(); c.track:SetAnchor(TOPLEFT, p, TOPLEFT, 0, 470); c.track:SetDimensions(740, 14)
	c.fill:ClearAnchors(); c.fill:SetAnchor(TOPLEFT, p, TOPLEFT, 1, 471); c.fill:SetDimensions(2, 12)
	c.progressText = label(p, "", 0, 488, 740, 20, "ZoFontGameBold", COLOR_HEAD)
	c.reason = label(p, "", 0, 508, 740, 22, "ZoFontGameSmall", COLOR_DIM)
	-- the groups that fold behind a button when the window is small, and the buttons that open them
	c.toolControls = {}
	for _, item in ipairs(c.inserts) do c.toolControls[#c.toolControls + 1] = item end
	for _, item in ipairs({ c.polish, c.undo, c.clear, c.stats, c.useCurrent }) do c.toolControls[#c.toolControls + 1] = item end
	popButton("tools", p, "POP_TOOLS"); popButton("options", p, "POP_OPTIONS"); popButton("preview", p, "POP_PREVIEW")
	c.optionControls = { c.lblMax, c.maxChars.backdrop, c.lblPrefix, c.prefix.backdrop, c.lblSuffix, c.suffix.backdrop, c.lblMarkers, c.markers.container, c.apply,
		c.sentences, c.paragraphs, c.tagToggle, c.sound, c.markerMode }
	c.previewControls = { c.previewTitle, c.previewPrev, c.previewNext, c.preview.backdrop }
end

local function buildSessions()
	local p = c.sessions
	c.sessionCombo = combo(p, 0, 0, 300)
	c.sessionName = edit(p, 310, 0, 250, 28, false, 60)
	c.createSession = button(p, L("CREATE_SESSION"), 570, 0, 170, function()
		local session, err = RP.Sessions.Create(c.sessionName:GetText())
		if not session then setNotice(err); return end
		RP.Sessions.Select(session.id)
		c.sessionName:SetText("")
		setNotice(L("SESSION_CREATED"))
		rebuildSessionCombo()
		UI.Refresh()
	end)
	c.sessionInfo = label(p, "", 0, 36, 740, 22, "ZoFontGame", COLOR_HEAD)
	c.participantsLabel = label(p, "", 0, 62, 740, 22, "ZoFontGameSmall", COLOR_DIM)
	c.participants = edit(p, 0, 86, 740, 70, true)
	c.participants:SetFont("ZoFontGameSmall")
	c.participants:SetHandler("OnTextChanged", function(self)
		if not loadingParticipants and RP.Sessions.Current() then participantDraft = self:GetText(); UI.RefreshSessions() end
	end)
	c.saveParticipants = button(p, L("SAVE_PARTICIPANTS"), 0, 164, 160, function()
		local people, err = RP.Sessions.SetParticipants(c.participants:GetText())
		if not people then setNotice(err); return end
		participantDraft = nil
		setNotice(L("PARTICIPANTS_SAVED"))
		UI.RefreshSessions()
	end)
	c.record = button(p, "", 170, 164, 200, function()
		local enabled = not RP.Sessions.IsRecording()
		local ok, err = RP.Sessions.SetRecording(enabled)
		if not ok then setNotice(err); return end
		setNotice(L(enabled and "RECORDING_ON_NOTICE" or "RECORDING_OFF_NOTICE"))
		UI.RefreshSessions()
	end)
	c.addonOnly = button(p, "", 380, 164, 210, function()
		local session = RP.Sessions.Current()
		if session then RP.Sessions.SetAddonOnly(not session.addonOnly); UI.RefreshSessions() end
	end)
	tip(c.addonOnly, L("ADDON_ONLY_TIP"))
	c.delete = button(p, L("DELETE_SESSION"), 600, 164, 140, function()
		local session = RP.Sessions.Current()
		if not session then return end
		if not deleteArmed then
			deleteArmed = true
			zo_callLater(function() deleteArmed = false; UI.RefreshSessions() end, 3000)
			UI.RefreshSessions()
			return
		end
		deleteArmed = false
		RP.Sessions.Delete(session.id)
		setNotice(L("SESSION_DELETED"))
		rebuildSessionCombo()
		UI.Refresh()
	end)
	c.recordWarning = label(p, "", 0, 202, 740, 40, "ZoFontGameSmall", COLOR_DIM)
	c.historyTitle = label(p, "", 0, 252, 420, 22, "ZoFontGameBold", COLOR_HEAD)
	c.historyOrder = button(p, "", 430, 248, 190, function() RP.sv.historyNewestFirst = not (RP.sv.historyNewestFirst == true); UI.RefreshSessions() end, 26)
	c.historyPrev = button(p, "<", 628, 248, 50, function() historyPage = historyPage - 1; historyKey = nil; UI.RefreshSessions() end, 26)
	c.historyNext = button(p, ">", 690, 248, 50, function() historyPage = historyPage + 1; historyKey = nil; UI.RefreshSessions() end, 26)
	c.history = edit(p, 0, 280, 740, 196, true)
	c.history:SetFont("ZoFontGameSmall")
	c.selectAll = button(p, L("SELECT_ALL"), 0, 484, 150, function() c.history:TakeFocus(); c.history:SelectAll() end, 26)
	tip(c.selectAll, L("SELECT_ALL_TIP"))
	popButton("session", p, "POP_SESSION"); popButton("people", p, "POP_PEOPLE"); popButton("recording", p, "POP_RECORDING")
end

local function buildLibrary()
	local p = c.library
	c.libHelp = label(p, L("LIB_HELP"), 0, 0, 740, 44, "ZoFontGameSmall", COLOR_DIM)
	c.libNameLabel = label(p, L("LIB_NAME"), 0, 52, 70, 22, "ZoFontGame", COLOR_HEAD)
	c.libName = edit(p, 76, 48, 330, 28, false, 60)
	-- Stores the composer text under a name (replacing an entry of the same name). Returns true when saved.
	function UI.SaveToLibrary(name)
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		local text = c.composer:GetText()
		if name == "" then setNotice(L("LIB_NEED_NAME")); return false end
		if text:match("^%s*$") then setNotice(L("LIB_NEED_TEXT")); return false end
		local existing = nil
		for _, entry in ipairs(RP.sv.library) do if entry.name == name then existing = entry; break end end
		if existing then existing.text = text
		else
			if #RP.sv.library >= 60 then setNotice(L("LIB_LIMIT")); return false end
			existing = { id = RP.sv.nextLibraryId, name = name, text = text, created = GetTimeStamp() }
			RP.sv.nextLibraryId = RP.sv.nextLibraryId + 1
			RP.sv.library[#RP.sv.library + 1] = existing
		end
		libSelected = existing.id
		setNotice(L("NOTICE_SAVED"))
		rebuildLibraryCombo()
		return true
	end
	c.libSave = button(p, L("LIB_SAVE"), 416, 48, 220, function()
		if UI.SaveToLibrary(c.libName:GetText()) then c.libName:SetText("") end
	end)
	c.libCombo = combo(p, 0, 92, 740)
	c.libLoad = button(p, L("LIB_LOAD"), 0, 128, 150, function()
		local entry = libSelected and findLibrary(libSelected)
		if not entry then setNotice(L("LIB_SELECT")); return end
		undoText = c.composer:GetText()
		setComposerText(entry.text)
		setNotice(L("NOTICE_LOADED"))
		changeTab("compose")
	end)
	c.libInsert = button(p, L("LIB_INSERT"), 160, 128, 190, function()
		local entry = libSelected and findLibrary(libSelected)
		if not entry then setNotice(L("LIB_SELECT")); return end
		changeTab("compose")
		insertAtCursor(entry.text)
		setNotice(L("NOTICE_INSERTED"))
	end)
	c.libDelete = button(p, L("LIB_DELETE"), 360, 128, 140, function()
		local entry, index = libSelected and findLibrary(libSelected)
		if not entry then return end
		if not libDeleteArmed then
			libDeleteArmed = true
			zo_callLater(function() libDeleteArmed = false; if initialized then refreshLibraryPreview() end end, 3000)
			refreshLibraryPreview()
			return
		end
		libDeleteArmed = false
		table.remove(RP.sv.library, index)
		libSelected = nil
		setNotice(L("NOTICE_DELETED"))
		rebuildLibraryCombo()
	end)
	c.libEmpty = label(p, L("LIB_EMPTY"), 0, 172, 740, 40, "ZoFontGame", COLOR_DIM)
	c.libPreview = edit(p, 0, 216, 740, 260, true)
	popButton("libsave", p, "POP_SAVE")
end

local function buildBar()
	local bar = tomRoleplayBar
	c.bar = bar
	c.barTitle = label(bar, "", 14, 8, 360, 22, "ZoFontGameBold", COLOR_HEAD)
	c.barReason = label(bar, "", 14, 30, 472, 20, "ZoFontGameSmall", COLOR_DIM)
	c.barTrack = tomRoleplayBarTrack
	c.barFill = tomRoleplayBarFill
	c.barTrack:ClearAnchors(); c.barTrack:SetAnchor(TOPLEFT, bar, TOPLEFT, 10, 54); c.barTrack:SetDimensions(480, 14)
	c.barFill:ClearAnchors(); c.barFill:SetAnchor(TOPLEFT, bar, TOPLEFT, 11, 55); c.barFill:SetDimensions(2, 12)
	c.barPause = button(bar, L("PAUSE"), 10, 76, 100, function()
		local ok, err
		if Q.paused then ok, err = Q.Resume() else ok, err = Q.Pause(L("Q_PAUSED")) end
		if not ok and err then setNotice(err) end
	end, 26)
	c.barPrevious = button(bar, L("PREVIOUS"), 116, 76, 100, function() setNotice(L("PREVIOUS_WARNING")); local ok, err = Q.Move(-1); if not ok and err then setNotice(err) end end, 26)
	c.barNext = button(bar, L("NEXT"), 222, 76, 100, function() local ok, err = Q.Move(1); if not ok and err then setNotice(err) end end, 26)
	c.barCancel = button(bar, L("CANCEL"), 328, 76, 80, function() Q.Cancel() end, 26)
	c.barOpen = button(bar, L("BAR_OPEN"), 414, 76, 76, function() UI.Show() end, 26)
end

function UI.Init()
	if initialized then return true end
	c.main = tomRoleplay
	if not c.main then return nil end
	-- window position remembered between sessions
	local position = RP.sv.window
	c.main:ClearAnchors()
	if type(position.left) == "number" and type(position.top) == "number" then c.main:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.left, position.top)
	else c.main:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end
	local bpos = RP.sv.bar
	tomRoleplayBar:ClearAnchors()
	if type(bpos.left) == "number" and type(bpos.top) == "number" then tomRoleplayBar:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, bpos.left, bpos.top)
	else tomRoleplayBar:SetAnchor(TOP, GuiRoot, TOP, 0, 110) end
	c.main:SetHandler("OnShow", function() SetGameCameraUIMode(true) end)
	-- size remembered between sessions (kept inside the allowed range)
	local size = RP.sv.size or {}
	c.main:SetDimensions(math.max(MIN_W, math.min(MAX_W, tonumber(size.width) or DEFAULT_W)), math.max(MIN_H, math.min(MAX_H, tonumber(size.height) or DEFAULT_H)))
	tomRoleplayBar:SetDimensions(math.max(BAR_MIN_W, math.min(BAR_MAX_W, tonumber(RP.sv.barWidth) or 500)), BAR_H)

	-- header: icon, title, help, close
	c.icon = makeControl(c.main, CT_TEXTURE, 8, 4, 32, 32)
	c.icon:SetTexture("EsoUI/Art/Help/help_tabIcon_emotes_up.dds")
	-- the TOM bubble: shows the main window and closes this panel
	c.tomBubble = makeControl(c.main, CT_BUTTON, 44, 6, 30, 30)
	c.tomBubble:SetMouseEnabled(true)
	c.tomBubble:SetNormalTexture("/esoui/art/chatwindow/chat_notification_up.dds")
	c.tomBubble:SetHandler("OnClicked", function()
		if tomUI.showMainWindow then tomUI.showMainWindow() end
		UI.Hide()
	end)
	tip(c.tomBubble, L("BACK_TO_TOM_TIP"))
	c.title = label(c.main, L("TITLE"), 80, 10, 300, 24, "ZoFontGameBold", COLOR_TEXT)
	c.closeButton = makeControl(c.main, CT_BUTTON, 740, 6, 30, 30)
	c.closeButton:SetMouseEnabled(true)
	c.closeButton:SetNormalTexture("/esoui/art/buttons/cancel_up.dds")
	c.closeButton:SetHandler("OnClicked", function() UI.Hide() end)
	tip(c.closeButton, L("CLOSE_TIP"))
	c.help = makeControl(c.main, CT_BUTTON, 706, 8, 26, 26)
	c.help:SetMouseEnabled(true)
	c.help:SetNormalTexture("/esoui/art/buttons/info_down.dds")
	tip(c.help, L("HELP_BODY"))
	c.line = makeControl(c.main, CT_TEXTURE, 10, 42, 760, 2)
	c.line:SetTexture("/esoui/art/miscellaneous/centerscreen_topdivider.dds")

	c.popBtn = {}
	c.tabMenu = button(c.main, "", 20, 52, 170, function() UI.TogglePopup("tabs") end)
	c.tabMenu:SetHidden(true)
	c.popBtn.tabs = c.tabMenu
	c.tabCompose = button(c.main, L("TAB_COMPOSE"), 20, 52, 140, function() changeTab("compose") end)
	c.tabSessions = button(c.main, L("TAB_SESSIONS"), 170, 52, 140, function() changeTab("sessions") end)
	c.tabLibrary = button(c.main, L("TAB_LIBRARY"), 320, 52, 140, function() changeTab("library") end)
	c.compose = makeControl(c.main, CT_CONTROL, 20, 92, 740, 530)
	c.sessions = makeControl(c.main, CT_CONTROL, 20, 92, 740, 530)
	c.library = makeControl(c.main, CT_CONTROL, 20, 92, 740, 530)
	c.status = label(c.main, "", 20, 626, 740, 22, "ZoFontGameSmall", COLOR_HEAD)
	c.version = label(c.main, "v" .. RP.version, 20, 650, 740, 16, "ZoFontGameSmall", COLOR_DIM)
	c.version:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

	buildCompose()
	buildSessions()
	buildLibrary()
	buildBar()
	initialized = true
	enableResize()
	UI.LayoutBar(true)

	-- restore what the player had: settings, destination, the unsent text
	fillSettingFields()
	rebuildDestinations()
	local saved = RP.sv.destination
	if saved and saved.target then c.target:SetText(saved.target) end
	UI.OnDestinationChanged()
	if RP.sv.draft and RP.sv.draft ~= "" then
		c.composer:SetText(RP.sv.draft)
		setNotice(L("NOTICE_DRAFT_RESTORED"))
	end
	-- an interrupted post is offered back through the Continue button; its destination is selected again
	local p = RP.sv.progress
	if p and p.channel then
		for index, entry in ipairs(destList) do
			if entry.channel == p.channel then destIndex = index; c.destination:SelectItemByIndex(index, true); break end
		end
		if p.target then c.target:SetText(p.target) end
		UI.OnDestinationChanged()
	end
	changeTab("compose")
	runAnalysis()
	-- a saved size smaller than the Compose tab needs (for example after the text size changed) is raised to fit
	local needed = UI.MinimumHeight(c.main:GetWidth() )
	if c.main:GetHeight() < needed then c.main:SetDimensions(c.main:GetWidth(), needed) end
	UI.UpdateLimits()
	UI.Layout(true)
	return true
end

--===============================================================================================================
-- SHOW / HIDE
--===============================================================================================================
function UI.Show()
	if not initialized then return end
	rebuildDestinations()
	UI.OnDestinationChanged()
	c.main:SetHidden(false)
	UI.Layout(true)
	UI.Refresh()
	-- once more a moment later, in case the game finished sizing something after the panel appeared
	zo_callLater(function() if initialized and not c.main:IsHidden() then UI.Layout(true) end end, 100)
end

function UI.Hide()
	if not initialized then return end
	blur()
	ClearTooltip(InformationTooltip)
	UI.ClosePopup()
	c.main:SetHidden(true)
	UI.Refresh()
end

function UI.Toggle()
	if not initialized then setNotice(L("NOT_READY")); return end
	if c.main:IsHidden() then UI.Show() else UI.Hide() end
end

-- entry points used by tom.xml and bindings.xml (tomUI is TOM's own global table)
function tomUI.roleplayClick()
	if RP.ready and initialized then
		local opening = c.main:IsHidden()
		UI.Toggle()
		-- setting "keepTomOpenForRoleplay" off: opening the panel closes the main TOM window
		if opening and tomUI.roleplayOpened then tomUI.roleplayOpened() end
	else d("[TOM-RP] " .. L("NOT_READY")) end
end

function tomUI.roleplayTooltip(self)
	showTip(self, L("BUTTON_TIP"))
end

function tomUI.roleplayMoveStop(self)
	if not RP.sv then return end
	RP.sv.window = { left = self:GetLeft(), top = self:GetTop() }
	self:ClearAnchors()
	self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RP.sv.window.left, RP.sv.window.top)
end

function tomUI.roleplayBarMoveStop(self)
	if not RP.sv then return end
	RP.sv.bar = { left = self:GetLeft(), top = self:GetTop() }
	self:ClearAnchors()
	self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RP.sv.bar.left, RP.sv.bar.top)
end

return UI
