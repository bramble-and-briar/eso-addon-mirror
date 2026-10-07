local addon = BureauOfPrivateDispatches
local private = addon.private
local CONFIG = addon.config

local GetString = GetString
local type = type
local tostring = tostring
local select = select
local unpack = unpack
local tableinsert = table.insert
local tableremove = table.remove

local CleanMessageText = private.CleanMessageText
local mathfloor = math.floor
local mathceil = math.ceil
local mathmax = math.max
local mathmin = math.min

local FOLLOW_UP_PENDING = "pending"
local FOLLOW_UP_WAITING = "waiting"
local FOLLOW_UP_OVERDUE = "overdue"
local FOLLOW_UP_ANSWERED = "answered"

addon.followUpStates =
{
	PENDING = FOLLOW_UP_PENDING,
	WAITING = FOLLOW_UP_WAITING,
	OVERDUE = FOLLOW_UP_OVERDUE,
	ANSWERED = FOLLOW_UP_ANSWERED,
}

-- Runtime notification model. The dictionary provides O(1) sender lookup and
-- the array owns newest-first presentation order.
addon.notificationsBySender = {}
addon.senderOrder = {}
addon.nextRevision = 0
addon.latestNotificationSenderId = nil
addon.latestNotificationRevision = nil
addon.latestReminderSenderId = nil
addon.latestReminderRevision = nil
addon.replyTargetSenderId = nil
addon.replyTargetOpenedMs = nil
addon.focusedSenderId = nil
addon.pendingChatEvents = {}
addon.whisperRestoreApplied = false
addon.whisperPersistSuppressed = false
addon.suppressArrivalCues = false
addon.dismissedTape = {}
addon.overflowPage = 0
addon.dndUntilStamp = nil
addon.lastIncomingSoundMs = nil
addon.wasDndActive = false

local function ClampNumber(value, minimum, maximum, fallback)
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	if value < minimum then
		return minimum
	end
	if value > maximum then
		return maximum
	end
	return value
end

function addon:GetFollowUpWaitingMs()
	local defaultSeconds = CONFIG.FOLLOW_UP_WAITING_MS / 1000
	local seconds = self.savedVariables ~= nil and self.savedVariables.followUpWaitingSeconds or defaultSeconds
	seconds = ClampNumber(
		seconds,
		CONFIG.FOLLOW_UP_WAITING_SECONDS_MIN,
		CONFIG.FOLLOW_UP_WAITING_SECONDS_MAX,
		defaultSeconds
	)
	return mathfloor(seconds) * 1000
end

function addon:GetFollowUpOverdueMs()
	local waitingSeconds = self:GetFollowUpWaitingMs() / 1000
	local minOverdue = mathmax(
		CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MIN,
		waitingSeconds + CONFIG.FOLLOW_UP_OVERDUE_GAP_SECONDS
	)
	local defaultSeconds = CONFIG.FOLLOW_UP_OVERDUE_MS / 1000
	local seconds = self.savedVariables ~= nil and self.savedVariables.followUpOverdueSeconds or defaultSeconds
	seconds = ClampNumber(seconds, minOverdue, CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MAX, defaultSeconds)
	if seconds < minOverdue then
		seconds = minOverdue
	end
	return mathfloor(seconds) * 1000
end

function addon:GetFollowUpReplyGraceMs()
	local defaultSeconds = CONFIG.FOLLOW_UP_REPLY_GRACE_MS / 1000
	local seconds = self.savedVariables ~= nil and self.savedVariables.followUpReplyGraceSeconds or defaultSeconds
	seconds = ClampNumber(
		seconds,
		CONFIG.FOLLOW_UP_REPLY_GRACE_SECONDS_MIN,
		CONFIG.FOLLOW_UP_REPLY_GRACE_SECONDS_MAX,
		defaultSeconds
	)
	return mathfloor(seconds) * 1000
end

function addon:GetFollowUpAnsweredVisibleMs()
	local defaultSeconds = CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_MS / 1000
	local seconds = self.savedVariables ~= nil and self.savedVariables.followUpAnsweredVisibleSeconds or defaultSeconds
	seconds = ClampNumber(
		seconds,
		CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MIN,
		CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MAX,
		defaultSeconds
	)
	return mathfloor(seconds) * 1000
end

function addon:SetFollowUpWaitingSeconds(seconds)
	if self.savedVariables == nil then
		return false
	end

	seconds = ClampNumber(
		seconds,
		CONFIG.FOLLOW_UP_WAITING_SECONDS_MIN,
		CONFIG.FOLLOW_UP_WAITING_SECONDS_MAX,
		CONFIG.FOLLOW_UP_WAITING_MS / 1000
	)
	self.savedVariables.followUpWaitingSeconds = mathfloor(seconds)
	local minOverdue = self.savedVariables.followUpWaitingSeconds + CONFIG.FOLLOW_UP_OVERDUE_GAP_SECONDS
	if (self.savedVariables.followUpOverdueSeconds or 0) < minOverdue then
		self.savedVariables.followUpOverdueSeconds = mathmin(minOverdue, CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MAX)
	end
	return true
end

function addon:SetFollowUpOverdueSeconds(seconds)
	if self.savedVariables == nil then
		return false
	end

	local waitingSeconds = self:GetFollowUpWaitingMs() / 1000
	local minOverdue = mathmax(
		CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MIN,
		waitingSeconds + CONFIG.FOLLOW_UP_OVERDUE_GAP_SECONDS
	)
	seconds = ClampNumber(seconds, minOverdue, CONFIG.FOLLOW_UP_OVERDUE_SECONDS_MAX, CONFIG.FOLLOW_UP_OVERDUE_MS / 1000)
	self.savedVariables.followUpOverdueSeconds = mathfloor(seconds)
	return true
end

function addon:SetFollowUpReplyGraceSeconds(seconds)
	if self.savedVariables == nil then
		return false
	end

	seconds = ClampNumber(
		seconds,
		CONFIG.FOLLOW_UP_REPLY_GRACE_SECONDS_MIN,
		CONFIG.FOLLOW_UP_REPLY_GRACE_SECONDS_MAX,
		CONFIG.FOLLOW_UP_REPLY_GRACE_MS / 1000
	)
	self.savedVariables.followUpReplyGraceSeconds = mathfloor(seconds)
	return true
end

function addon:SetFollowUpAnsweredVisibleSeconds(seconds)
	if self.savedVariables == nil then
		return false
	end

	seconds = ClampNumber(
		seconds,
		CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MIN,
		CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_SECONDS_MAX,
		CONFIG.FOLLOW_UP_ANSWERED_VISIBLE_MS / 1000
	)
	self.savedVariables.followUpAnsweredVisibleSeconds = mathfloor(seconds)
	return true
end

function addon:UsesPChatPreview()
	return self.savedVariables == nil or self.savedVariables.usePChatPreview ~= false
end

function addon:SetUsePChatPreview(enabled)
	if self.savedVariables == nil then
		return false
	end
	self.savedVariables.usePChatPreview = enabled == true
	return self.savedVariables.usePChatPreview
end

local function CurrentUnixStamp()
	if type(GetTimeStamp) ~= "function" then
		return nil
	end

	local stamp = GetTimeStamp()
	if type(stamp) ~= "number" or stamp ~= stamp then
		return nil
	end

	return stamp
end

local function GameTimeFromStamp(stamp, nowMs, nowStamp)
	if type(stamp) ~= "number" or stamp ~= stamp or type(nowStamp) ~= "number" then
		return nowMs
	end

	local ageSeconds = nowStamp - stamp
	if ageSeconds < 0 then
		ageSeconds = 0
	end

	return nowMs - ageSeconds * 1000
end

local function CollectAliasList(aliases)
	local copied = {}
	if type(aliases) ~= "table" then
		return copied
	end

	if aliases[1] ~= nil then
		for index = 1, #aliases do
			local alias = aliases[index]
			if type(alias) == "string" and alias ~= "" then
				copied[#copied + 1] = alias
			end
		end
		return copied
	end

	for alias in pairs(aliases) do
		if type(alias) == "string" and alias ~= "" then
			copied[#copied + 1] = alias
		end
	end

	return copied
end

local function NormalizeSenderAlias(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	local normalized = zo_strlower(zo_strtrim(zo_strformat("<<1>>", value)))
	if normalized == "" then
		return nil
	end

	return normalized
end

local function AddSenderAlias(entry, value)
	local alias = NormalizeSenderAlias(value)
	if alias == nil then
		return
	end

	entry.senderAliases = entry.senderAliases or {}
	entry.senderAliases[alias] = true
end

local function CanUseReplyTargetFallback(fromName, fromDisplayName)
	local normalizedName = NormalizeSenderAlias(fromName)
	local normalizedDisplayName = NormalizeSenderAlias(fromDisplayName)
	local playerName = type(GetUnitName) == "function" and GetUnitName("player") or nil
	local playerDisplayName = type(GetUnitDisplayName) == "function"
		and GetUnitDisplayName("player") or nil
	local playerAliases =
	{
		[NormalizeSenderAlias(playerName) or false] = true,
		[NormalizeSenderAlias(playerDisplayName) or false] = true,
	}

	if normalizedName ~= nil and not playerAliases[normalizedName] then
		return false
	end
	if normalizedDisplayName ~= nil and not playerAliases[normalizedDisplayName] then
		return false
	end

	return true
end

local function RemoveSenderEntry(self, senderId, orderAlreadyRemoved)
	if senderId == nil or self.notificationsBySender[senderId] == nil then
		return false
	end

	self.notificationsBySender[senderId] = nil
	if self.latestNotificationSenderId == senderId then
		self.latestNotificationSenderId = nil
		self.latestNotificationRevision = nil
	end
	if self.latestReminderSenderId == senderId then
		self.latestReminderSenderId = nil
		self.latestReminderRevision = nil
	end
	if self.replyTargetSenderId == senderId then
		self.replyTargetSenderId = nil
		self.replyTargetOpenedMs = nil
	end
	if self.focusedSenderId == senderId then
		self.focusedSenderId = nil
	end

	if not orderAlreadyRemoved then
		for index, orderedSenderId in ipairs(self.senderOrder) do
			if orderedSenderId == senderId then
				tableremove(self.senderOrder, index)
				break
			end
		end
	end

	return true
end

local function CopyEntryForTape(entry)
	return
	{
		senderId = entry.senderId,
		preview = entry.preview,
		unreadCount = entry.unreadCount or 0,
		lastMessageMs = entry.lastMessageMs,
		lastMessageStamp = entry.lastMessageStamp,
		characterName = entry.characterName,
		aliases = CollectAliasList(entry.senderAliases),
	}
end

function addon:RemoveTapeEntry(senderId)
	if senderId == nil then
		return false
	end

	local tape = self.dismissedTape
	local removed = false
	for index = #tape, 1, -1 do
		if tape[index] ~= nil and tape[index].senderId == senderId then
			tableremove(tape, index)
			removed = true
		end
	end

	return removed
end

function addon:PushDismissedEntry(entry)
	if entry == nil or type(entry.senderId) ~= "string" or entry.senderId == "" then
		return
	end
	if entry.followUpState == FOLLOW_UP_ANSWERED then
		return
	end

	self:RemoveTapeEntry(entry.senderId)
	tableinsert(self.dismissedTape, 1, CopyEntryForTape(entry))
	while #self.dismissedTape > CONFIG.MAX_DISMISSED_TAPE do
		self.dismissedTape[#self.dismissedTape] = nil
	end
end

function addon:FindTapeSender(fromName, fromDisplayName)
	local aliases = {}
	local normalizedName = NormalizeSenderAlias(fromName)
	local normalizedDisplayName = NormalizeSenderAlias(fromDisplayName)
	if normalizedName ~= nil then
		aliases[normalizedName] = true
	end
	if normalizedDisplayName ~= nil then
		aliases[normalizedDisplayName] = true
	end

	for index, stored in ipairs(self.dismissedTape) do
		if stored ~= nil then
			if aliases[NormalizeSenderAlias(stored.senderId) or false] then
				return index, stored
			end

			local storedAliases = CollectAliasList(stored.aliases)
			for aliasIndex = 1, #storedAliases do
				if aliases[NormalizeSenderAlias(storedAliases[aliasIndex]) or false] then
					return index, stored
				end
			end
		end
	end

	return nil, nil
end

function addon:GetVisibleSenderLimit()
	local limit = self.savedVariables ~= nil and self.savedVariables.visibleSenderLimit
		or CONFIG.DEFAULT_VISIBLE_SENDERS
	if limit == CONFIG.DEFAULT_VISIBLE_SENDERS or limit == 8 or limit == CONFIG.MAX_VISIBLE_SENDERS then
		return limit
	end
	return CONFIG.DEFAULT_VISIBLE_SENDERS
end

function addon:SetVisibleSenderLimit(limit)
	if self.savedVariables == nil
		or (limit ~= CONFIG.DEFAULT_VISIBLE_SENDERS and limit ~= 8 and limit ~= CONFIG.MAX_VISIBLE_SENDERS) then
		return false
	end

	self.savedVariables.visibleSenderLimit = limit
	self.overflowPage = 0
	self:RefreshNotifications()
	return true
end

function addon:GetOverflowPageCount()
	local total = #self.senderOrder
	local pageSize = self:GetVisibleSenderLimit()
	if total <= pageSize then
		return 1
	end

	return mathceil(total / pageSize)
end

function addon:NormalizeOverflowPage()
	local pageCount = self:GetOverflowPageCount()
	if pageCount <= 1 then
		self.overflowPage = 0
		return
	end

	local page = self.overflowPage or 0
	if type(page) ~= "number" or page ~= page or page < 0 then
		page = 0
	end
	page = mathfloor(page)
	if page >= pageCount then
		page = 0
	end
	self.overflowPage = page
end

function addon:CycleOverflowPage()
	self:NormalizeOverflowPage()
	local pageCount = self:GetOverflowPageCount()
	if pageCount <= 1 then
		return false
	end

	self.overflowPage = (self.overflowPage + 1) % pageCount
	self:RefreshNotifications()
	return true
end

function addon:GetWhisperRestoreBucket()
	if self.savedVariables == nil then
		return nil, nil
	end

	if type(GetCurrentCharacterId) ~= "function" then
		return nil, nil
	end

	local characterId = GetCurrentCharacterId()
	if characterId == nil then
		return nil, nil
	end

	characterId = tostring(characterId)
	if characterId == "" then
		return nil, nil
	end

	local store = self.savedVariables.whisperRestore
	if type(store) ~= "table" then
		store = {}
		self.savedVariables.whisperRestore = store
	end

	return store, characterId
end

function addon:PruneWhisperRestoreStore(store, keepCharacterId, nowStamp)
	if type(store) ~= "table" then
		return
	end

	local maxAge = CONFIG.WHISPER_RESTORE_MAX_AGE_SECONDS
	local candidates = {}
	for characterId, snapshot in pairs(store) do
		local savedAt = type(snapshot) == "table" and snapshot.savedAt or nil
		local isStale = type(nowStamp) == "number"
			and type(savedAt) == "number"
			and nowStamp - savedAt > maxAge
		if type(snapshot) ~= "table"
			or type(snapshot.senders) ~= "table"
			or #snapshot.senders == 0
			or isStale then
			store[characterId] = nil
		else
			local senders = snapshot.senders
			for senderIndex = 1, #senders do
				local stored = senders[senderIndex]
				if type(stored) == "table" then
					stored.preview = nil
					stored.message = nil
					stored.text = nil
				end
			end
			if characterId ~= keepCharacterId then
				candidates[#candidates + 1] =
				{
					characterId = characterId,
					savedAt = type(savedAt) == "number" and savedAt or 0,
				}
			end
		end
	end

	table.sort(candidates, function(left, right)
		return left.savedAt > right.savedAt
	end)

	local maxOtherCharacters = mathmax(CONFIG.WHISPER_RESTORE_MAX_CHARACTERS - 1, 0)
	for index = maxOtherCharacters + 1, #candidates do
		store[candidates[index].characterId] = nil
	end
end

function addon:PersistWhisperRestore()
	if self.whisperPersistSuppressed or self.savedVariables == nil then
		return
	end

	local store, characterId = self:GetWhisperRestoreBucket()
	if store == nil or characterId == nil then
		return
	end

	local nowStamp = CurrentUnixStamp()
	local senders = {}
	local maxAge = CONFIG.WHISPER_RESTORE_MAX_AGE_SECONDS

	for _, senderId in ipairs(self.senderOrder) do
		local entry = self.notificationsBySender[senderId]
		if entry ~= nil
			and type(senderId) == "string"
			and senderId ~= ""
			and entry.followUpState ~= FOLLOW_UP_ANSWERED then
			local lastMessageStamp = entry.lastMessageStamp
			local isFresh = type(lastMessageStamp) ~= "number"
				or nowStamp == nil
				or nowStamp - lastMessageStamp <= maxAge
			if isFresh then
				senders[#senders + 1] =
				{
					senderId = senderId,
					unreadCount = mathmin(
						mathmax(mathfloor(entry.unreadCount or 0), 0),
						CONFIG.MAX_DISPLAYED_UNREAD
					),
					lastMessageStamp = lastMessageStamp,
					pendingSinceStamp = entry.pendingSinceStamp,
					reminderStage = mathmin(mathmax(mathfloor(entry.reminderStage or 0), 0), 2),
					aliases = CollectAliasList(entry.senderAliases),
				}
			end
		end

		if #senders >= CONFIG.MAX_TRACKED_SENDERS then
			break
		end
	end

	if #senders == 0 then
		store[characterId] = nil
		self:PruneWhisperRestoreStore(store, nil, nowStamp)
		return
	end

	store[characterId] =
	{
		savedAt = nowStamp,
		senders = senders,
	}
	self:PruneWhisperRestoreStore(store, characterId, nowStamp)
end

local function GetPChatLineStrings()
	if type(pChat) ~= "table" then
		return nil, nil
	end

	local db = pChat.db
	if type(db) ~= "table" or type(db.LineStrings) ~= "table" then
		return nil, nil
	end

	return db.LineStrings, db
end

local function CollectPChatSenderKeys(line, keys)
	if type(line) ~= "table" then
		return
	end

	local rawFrom = NormalizeSenderAlias(line.rawFrom)
	if rawFrom ~= nil then
		keys[rawFrom] = true
	end

	local function CollectAtNames(text)
		if type(text) ~= "string" or text == "" then
			return
		end

		for name in string.gmatch(text, "@[%w_%-%.]+") do
			local alias = NormalizeSenderAlias(name)
			if alias ~= nil then
				keys[alias] = true
			end
		end
	end

	CollectAtNames(line.rawFrom)
	CollectAtNames(line.rawValue)
	CollectAtNames(line.rawLine)
end

local function PChatLineMatchesSender(line, senderKeys)
	if senderKeys == nil then
		return false
	end

	local keys = {}
	CollectPChatSenderKeys(line, keys)
	for alias in pairs(keys) do
		if senderKeys[alias] then
			return true
		end
	end

	return false
end

function addon:FindPChatWhisperPreview(entry)
	if entry == nil then
		return nil
	end

	local lines = GetPChatLineStrings()
	if lines == nil then
		return nil
	end

	local senderKeys = {}
	local senderAlias = NormalizeSenderAlias(entry.senderId)
	if senderAlias ~= nil then
		senderKeys[senderAlias] = true
	end
	if type(entry.senderAliases) == "table" then
		for alias in pairs(entry.senderAliases) do
			if type(alias) == "string" and alias ~= "" then
				senderKeys[alias] = true
			end
		end
	end
	if next(senderKeys) == nil then
		return nil
	end

	local lastMessageStamp = entry.lastMessageStamp
	local nowStamp = CurrentUnixStamp()
	local maxAge = CONFIG.WHISPER_RESTORE_MAX_AGE_SECONDS
	local slack = CONFIG.PCHAT_PREVIEW_TIMESTAMP_SLACK_SECONDS or 30
	local count = #lines
	local closestText = nil
	local closestDelta = nil
	local newestFallback = nil

	for index = count, 1, -1 do
		local line = lines[index]
		if type(line) == "table" and line.channel == CHAT_CHANNEL_WHISPER
			and PChatLineMatchesSender(line, senderKeys) then
			local text = CleanMessageText(line.rawMessage or line.rawText)
			if text ~= "" then
				local timestamp = line.rawTimestamp
				local isFresh = type(timestamp) ~= "number"
					or nowStamp == nil
					or (nowStamp - timestamp <= maxAge and timestamp <= nowStamp)
				if isFresh then
					if type(lastMessageStamp) == "number" and type(timestamp) == "number" then
						local delta = timestamp - lastMessageStamp
						if delta < 0 then
							delta = -delta
						end
						if delta <= slack and (closestDelta == nil or delta < closestDelta) then
							closestText = text
							closestDelta = delta
							if delta == 0 then
								break
							end
						elseif newestFallback == nil and timestamp <= lastMessageStamp + slack then
							newestFallback = text
						end
					elseif newestFallback == nil then
						newestFallback = text
					end
				end
			end
		end
	end

	return closestText or newestFallback
end

function addon:TryFillRestoredPreviewsFromPChat()
	if not self:UsesPChatPreview() then
		return false
	end

	local filled = false

	for _, senderId in ipairs(self.senderOrder) do
		local entry = self.notificationsBySender[senderId]
		if entry ~= nil and entry.previewIsPlaceholder then
			local preview = self:FindPChatWhisperPreview(entry)
			if type(preview) == "string" and preview ~= "" then
				entry.preview = preview
				entry.previewIsPlaceholder = nil
				filled = true
			end
		end
	end

	return filled
end

function addon:RestoreWhisperSnapshot()
	if self.whisperRestoreApplied then
		return false
	end

	local store, characterId = self:GetWhisperRestoreBucket()
	if store == nil or characterId == nil then
		return false
	end

	self.whisperRestoreApplied = true
	local snapshot = store[characterId]
	if type(snapshot) ~= "table" or type(snapshot.senders) ~= "table" then
		return false
	end

	local nowMs = GetGameTimeMilliseconds()
	local nowStamp = CurrentUnixStamp()
	local maxAge = CONFIG.WHISPER_RESTORE_MAX_AGE_SECONDS
	local restored = false

	self.whisperPersistSuppressed = true
	self.suppressArrivalCues = true

	for index = 1, #snapshot.senders do
		if #self.senderOrder >= CONFIG.MAX_TRACKED_SENDERS then
			break
		end

		local stored = snapshot.senders[index]
		if type(stored) == "table"
			and type(stored.senderId) == "string"
			and stored.senderId ~= ""
			and self.notificationsBySender[stored.senderId] == nil then
			local lastMessageStamp = stored.lastMessageStamp
			local isFresh = type(lastMessageStamp) ~= "number"
				or nowStamp == nil
				or nowStamp - lastMessageStamp <= maxAge
			if isFresh then
				self.nextRevision = self.nextRevision + 1

				local unreadCount = 1
				if type(stored.unreadCount) == "number" then
					unreadCount = mathmin(
						mathmax(mathfloor(stored.unreadCount), 0),
						CONFIG.MAX_DISPLAYED_UNREAD
					)
				end

				local preview = GetString(SI_BPD_NOTIFICATION_RESTORED)

				local reminderStage = 0
				if type(stored.reminderStage) == "number" then
					reminderStage = mathmin(mathmax(mathfloor(stored.reminderStage), 0), 2)
				end

				local lastMessageMs = GameTimeFromStamp(lastMessageStamp, nowMs, nowStamp)
				local pendingSinceStamp = stored.pendingSinceStamp
				if type(pendingSinceStamp) ~= "number" then
					pendingSinceStamp = lastMessageStamp
				end
				local pendingSinceMs = GameTimeFromStamp(pendingSinceStamp, nowMs, nowStamp)
				local age = nowMs - (pendingSinceMs or lastMessageMs or nowMs)
				local followUpState = FOLLOW_UP_PENDING
				if age >= self:GetFollowUpOverdueMs() then
					followUpState = FOLLOW_UP_OVERDUE
					if reminderStage < 2 then
						reminderStage = 2
					end
				elseif age >= self:GetFollowUpWaitingMs() then
					followUpState = FOLLOW_UP_WAITING
					if reminderStage < 1 then
						reminderStage = 1
					end
				end

				local entry =
				{
					senderId = stored.senderId,
					preview = preview,
					unreadCount = unreadCount,
					revision = self.nextRevision,
					incomingRevision = self.nextRevision,
					pulsedRevision = self.nextRevision,
					lastMessageMs = lastMessageMs,
					lastMessageStamp = lastMessageStamp,
					pendingSinceMs = pendingSinceMs,
					pendingSinceStamp = pendingSinceStamp,
					followUpState = followUpState,
					reminderStage = reminderStage,
					previewIsPlaceholder = true,
				}
				if reminderStage >= 2 then
					entry.reminderCueRevision = entry.incomingRevision
				end

				self.notificationsBySender[stored.senderId] = entry
				AddSenderAlias(entry, stored.senderId)
				local aliases = CollectAliasList(stored.aliases)
				for aliasIndex = 1, #aliases do
					AddSenderAlias(entry, aliases[aliasIndex])
				end
				self.senderOrder[#self.senderOrder + 1] = stored.senderId
				restored = true
			end
		end
	end

	self.suppressArrivalCues = false
	self.whisperPersistSuppressed = false

	if restored then
		self:TrimTrackedSenders()
		self:TryFillRestoredPreviewsFromPChat()
		self:PersistWhisperRestore()
		self:RefreshNotifications()
	else
		store[characterId] = nil
	end

	return restored
end

function addon:QueuePendingChatEvent(...)
	local channelType = select(2, ...)
	if channelType ~= CHAT_CHANNEL_WHISPER and channelType ~= CHAT_CHANNEL_WHISPER_SENT then
		return
	end

	local queue = self.pendingChatEvents
	queue[#queue + 1] = { ... }
	while #queue > CONFIG.WHISPER_RESTORE_MAX_QUEUED_EVENTS do
		tableremove(queue, 1)
	end
end

function addon:ReplayPendingChatEvents()
	local queue = self.pendingChatEvents
	self.pendingChatEvents = {}
	if #queue == 0 then
		return
	end

	local previousSuppressArrivalCues = self.suppressArrivalCues
	self.suppressArrivalCues = true
	for index = 1, #queue do
		local event = queue[index]
		if event ~= nil then
			self:OnChatMessageChannel(unpack(event))
		end
	end
	self.suppressArrivalCues = previousSuppressArrivalCues
end

function addon:MoveSenderToFront(senderId)
	for index, orderedSenderId in ipairs(self.senderOrder) do
		if orderedSenderId == senderId then
			tableremove(self.senderOrder, index)
			break
		end
	end

	tableinsert(self.senderOrder, 1, senderId)
end

function addon:PruneSenderOrder()
	local order = self.senderOrder
	local seen = {}
	local writeIndex = 1

	for readIndex = 1, #order do
		local senderId = order[readIndex]
		if self.notificationsBySender[senderId] ~= nil and not seen[senderId] then
			seen[senderId] = true
			order[writeIndex] = senderId
			writeIndex = writeIndex + 1
		end
	end

	for index = #order, writeIndex, -1 do
		order[index] = nil
	end
end

function addon:TrimTrackedSenders()
	local order = self.senderOrder
	while #order > CONFIG.MAX_TRACKED_SENDERS do
		local droppedSenderId = tableremove(order)
		if droppedSenderId ~= nil then
			RemoveSenderEntry(self, droppedSenderId, true)
		else
			break
		end
	end
end

function addon:AddOrUpdateNotification(senderId, message, fromName, fromDisplayName)
	if type(senderId) ~= "string" or senderId == "" then
		return
	end

	self:RemoveTapeEntry(senderId)

	local cleanedMessage = CleanMessageText(message)
	if cleanedMessage == "" then
		cleanedMessage = GetString(SI_BPD_NOTIFICATION_EMPTY)
	end

	self.nextRevision = self.nextRevision + 1

	local entry = self.notificationsBySender[senderId]
	if not entry then
		entry = { senderId = senderId, unreadCount = 0 }
		self.notificationsBySender[senderId] = entry
	end
	AddSenderAlias(entry, senderId)
	AddSenderAlias(entry, fromName)
	AddSenderAlias(entry, fromDisplayName)

	local now = GetGameTimeMilliseconds()
	local nowStamp = CurrentUnixStamp()
	if entry.followUpState == nil or entry.followUpState == FOLLOW_UP_ANSWERED then
		entry.pendingSinceMs = now
		entry.pendingSinceStamp = nowStamp
		entry.reminderStage = 0
	end

	entry.preview = cleanedMessage
	entry.previewIsPlaceholder = nil
	entry.revision = self.nextRevision
	entry.incomingRevision = entry.revision
	entry.unreadCount = (entry.unreadCount or 0) + 1
	entry.lastMessageMs = now
	entry.lastMessageStamp = nowStamp
	entry.followUpState = FOLLOW_UP_PENDING
	entry.answeredAtMs = nil
	entry.handledRevision = nil
	entry.characterName = type(fromName) == "string" and fromName ~= ""
		and zo_strformat("<<1>>", fromName) or entry.characterName
	self.latestNotificationSenderId = senderId
	self.latestNotificationRevision = entry.revision
	self.overflowPage = 0
	if self.suppressArrivalCues then
		entry.pulsedRevision = entry.revision
	end

	self:MoveSenderToFront(senderId)
	self:TrimTrackedSenders()
	if type(self.NotifyIncomingWhisper) == "function" then
		self:NotifyIncomingWhisper(entry)
	end
	self:PersistWhisperRestore()
	self:RefreshNotifications()
end

function addon:MarkSenderRead(senderId)
	local entry = self.notificationsBySender[senderId]
	if entry == nil or entry.followUpState == FOLLOW_UP_ANSWERED then
		return false
	end
	if (entry.unreadCount or 0) == 0 then
		return false
	end

	entry.unreadCount = 0
	entry.pulsedRevision = entry.revision
	if self.latestNotificationSenderId == senderId then
		self.latestNotificationSenderId = nil
		self.latestNotificationRevision = nil
	end

	self:PersistWhisperRestore()
	self:RefreshNotifications()
	return true
end

function addon:DismissSender(senderId)
	local entry = senderId ~= nil and self.notificationsBySender[senderId] or nil
	if entry ~= nil then
		self:PushDismissedEntry(entry)
	end
	if RemoveSenderEntry(self, senderId) then
		self:NormalizeOverflowPage()
		self:PersistWhisperRestore()
		self:RefreshNotifications()
	end
end

function addon:RestoreLastDismissed()
	local stored = self.dismissedTape[1]
	if stored == nil or type(stored.senderId) ~= "string" or stored.senderId == "" then
		tableremove(self.dismissedTape, 1)
		return false
	end
	if self.notificationsBySender[stored.senderId] ~= nil then
		tableremove(self.dismissedTape, 1)
		return false
	end
	tableremove(self.dismissedTape, 1)

	local now = GetGameTimeMilliseconds()
	local nowStamp = CurrentUnixStamp()
	self.nextRevision = self.nextRevision + 1

	local unreadCount = 0
	if type(stored.unreadCount) == "number" then
		unreadCount = mathmin(
			mathmax(mathfloor(stored.unreadCount), 0),
			CONFIG.MAX_DISPLAYED_UNREAD
		)
	end

	local preview = CleanMessageText(stored.preview)
	if preview == "" then
		preview = GetString(SI_BPD_NOTIFICATION_EMPTY)
	end

	local entry =
	{
		senderId = stored.senderId,
		preview = preview,
		unreadCount = unreadCount,
		revision = self.nextRevision,
		incomingRevision = self.nextRevision,
		pulsedRevision = self.nextRevision,
		lastMessageMs = stored.lastMessageMs or now,
		lastMessageStamp = stored.lastMessageStamp or nowStamp,
		pendingSinceMs = now,
		pendingSinceStamp = nowStamp,
		followUpState = FOLLOW_UP_PENDING,
		reminderStage = 0,
		characterName = stored.characterName,
	}
	AddSenderAlias(entry, stored.senderId)
	local aliases = CollectAliasList(stored.aliases)
	for aliasIndex = 1, #aliases do
		AddSenderAlias(entry, aliases[aliasIndex])
	end
	if type(stored.characterName) == "string" then
		AddSenderAlias(entry, stored.characterName)
	end

	self.notificationsBySender[stored.senderId] = entry
	self:MoveSenderToFront(stored.senderId)
	self.overflowPage = 0
	self:TrimTrackedSenders()
	self:PersistWhisperRestore()
	self:RefreshNotifications()
	return true
end

function addon:ClearAllNotifications()
	self.notificationsBySender = {}
	self.senderOrder = {}
	self.dismissedTape = {}
	self.overflowPage = 0
	self.latestNotificationSenderId = nil
	self.latestNotificationRevision = nil
	self.latestReminderSenderId = nil
	self.latestReminderRevision = nil
	self.replyTargetSenderId = nil
	self.replyTargetOpenedMs = nil
	self.focusedSenderId = nil
	self:PersistWhisperRestore()
	self:RefreshNotifications()
end

function addon:FindNotificationSender(fromName, fromDisplayName)
	local aliases = {}
	local normalizedName = NormalizeSenderAlias(fromName)
	local normalizedDisplayName = NormalizeSenderAlias(fromDisplayName)
	if normalizedName ~= nil then
		aliases[normalizedName] = true
	end
	if normalizedDisplayName ~= nil then
		aliases[normalizedDisplayName] = true
	end

	for _, senderId in ipairs(self.senderOrder) do
		local entry = self.notificationsBySender[senderId]
		if entry ~= nil and entry.senderAliases ~= nil then
			for alias in pairs(aliases) do
				if entry.senderAliases[alias] then
					return senderId
				end
			end
		end
	end

	return nil
end

local function EntryMatchesName(entry, value)
	local alias = NormalizeSenderAlias(value)
	if alias == nil or entry == nil then
		return false
	end
	if NormalizeSenderAlias(entry.senderId) == alias then
		return true
	end
	return entry.senderAliases ~= nil and entry.senderAliases[alias] == true
end

function addon:GetSenderRelation(entry)
	local relation =
	{
		isFriend = false,
		isGroup = false,
		isGuild = false,
		isIgnored = false,
		canMail = false,
		canTeleport = false,
		canIgnore = false,
		groupCharacterName = nil,
	}
	if entry == nil or type(entry.senderId) ~= "string" or entry.senderId == "" then
		return relation
	end

	if type(IsFriend) == "function" then
		relation.isFriend = IsFriend(entry.senderId) == true
	end
	if type(IsIgnored) == "function" then
		relation.isIgnored = IsIgnored(entry.senderId) == true
	end

	if type(GetGroupSize) == "function" then
		local groupSize = GetGroupSize() or 0
		for index = 1, groupSize do
			local unitTag = type(GetGroupUnitTagByIndex) == "function"
				and GetGroupUnitTagByIndex(index) or ("group" .. index)
			if unitTag ~= nil then
				local displayName = type(GetUnitDisplayName) == "function" and GetUnitDisplayName(unitTag) or nil
				local unitName = type(GetUnitName) == "function" and GetUnitName(unitTag) or nil
				if EntryMatchesName(entry, displayName) or EntryMatchesName(entry, unitName) then
					relation.isGroup = true
					if type(unitName) == "string" and unitName ~= "" then
						relation.groupCharacterName = zo_strformat("<<1>>", unitName)
					end
					break
				end
			end
		end
	end

	if type(GetNumGuilds) == "function" and type(GetGuildId) == "function" then
		local guildCount = GetNumGuilds() or 0
		for guildIndex = 1, guildCount do
			local guildId = GetGuildId(guildIndex)
			if type(GetGuildMemberIndexFromDisplayName) == "function"
				and GetGuildMemberIndexFromDisplayName(guildId, entry.senderId) ~= nil then
				relation.isGuild = true
				break
			end
		end
	end

	relation.canIgnore = true
	relation.canMail = MAIL_SEND ~= nil
	relation.canTeleport = relation.isGroup or relation.isFriend or relation.isGuild

	return relation
end

function addon:GetPrimaryRelationBadge(entry)
	local relation = self:GetSenderRelation(entry)
	if relation.isGroup then
		return "G", CONFIG.RELATION_GROUP_COLOR
	end
	if relation.isFriend then
		return "F", CONFIG.RELATION_FRIEND_COLOR
	end
	if relation.isGuild then
		return "#", CONFIG.RELATION_GUILD_COLOR
	end

	return nil
end

function addon:FindCurrentWhisperTargetSender()
	if CHAT_ROUTER == nil or type(CHAT_ROUTER.GetCurrentChannelData) ~= "function" then
		return nil, false
	end

	local channelData, channelTarget = CHAT_ROUTER:GetCurrentChannelData()
	if type(channelData) ~= "table"
		or (channelData.id ~= CHAT_CHANNEL_WHISPER and channelData.id ~= CHAT_CHANNEL_WHISPER_SENT)
		or NormalizeSenderAlias(channelTarget) == nil then
		return nil, false
	end

	return self:FindNotificationSender(channelTarget, channelTarget), true
end

function addon:MarkReplyOpened(senderId)
	local entry = self.notificationsBySender[senderId]
	if entry == nil or entry.followUpState == FOLLOW_UP_ANSWERED then
		return false
	end

	local now = GetGameTimeMilliseconds()
	entry.replyOpenedMs = now
	entry.followUpState = FOLLOW_UP_PENDING
	if self.replyTargetSenderId ~= nil and self.replyTargetSenderId ~= senderId then
		local previousEntry = self.notificationsBySender[self.replyTargetSenderId]
		if previousEntry ~= nil then
			previousEntry.replyOpenedMs = nil
		end
	end
	self.replyTargetSenderId = senderId
	self.replyTargetOpenedMs = now
	self:RefreshNotifications()
	return true
end

function addon:MarkSenderAnswered(senderId)
	local entry = self.notificationsBySender[senderId]
	if entry == nil then
		return false
	end

	entry.followUpState = FOLLOW_UP_ANSWERED
	entry.handledRevision = entry.incomingRevision
	entry.answeredAtMs = GetGameTimeMilliseconds()
	entry.replyOpenedMs = nil
	entry.unreadCount = 0
	self:RemoveTapeEntry(senderId)
	if self.latestNotificationSenderId == senderId then
		self.latestNotificationSenderId = nil
		self.latestNotificationRevision = nil
	end
	if self.latestReminderSenderId == senderId then
		self.latestReminderSenderId = nil
		self.latestReminderRevision = nil
	end
	if self.replyTargetSenderId == senderId then
		self.replyTargetSenderId = nil
		self.replyTargetOpenedMs = nil
	end

	self:PersistWhisperRestore()
	self:RefreshNotifications()
	return true
end

function addon:MarkOutgoingReply(fromName, fromDisplayName)
	local senderId = self:FindNotificationSender(fromName, fromDisplayName)
	local canUseTargetFallback = senderId == nil
		and CanUseReplyTargetFallback(fromName, fromDisplayName)
	local hasExplicitTarget = false
	if canUseTargetFallback then
		senderId, hasExplicitTarget = self:FindCurrentWhisperTargetSender()
	end
	if senderId == nil and hasExplicitTarget then
		return false
	end
	if senderId == nil
		and self.replyTargetSenderId ~= nil
		and canUseTargetFallback then
		local entry = self.notificationsBySender[self.replyTargetSenderId]
		if entry ~= nil
			and self.replyTargetOpenedMs ~= nil
			and GetGameTimeMilliseconds() - self.replyTargetOpenedMs
				<= CONFIG.FOLLOW_UP_REPLY_TARGET_MAX_AGE_MS then
			senderId = self.replyTargetSenderId
		else
			self.replyTargetSenderId = nil
			self.replyTargetOpenedMs = nil
		end
	end

	if senderId == nil then
		local tapeIndex = self:FindTapeSender(fromName, fromDisplayName)
		if tapeIndex ~= nil then
			tableremove(self.dismissedTape, tapeIndex)
			return true
		end
		return false
	end

	return self:MarkSenderAnswered(senderId)
end

function addon:UpdateFollowUps(now, canSignalReminder)
	now = now or GetGameTimeMilliseconds()
	local changed = false
	local answeredToRemove = {}
	local overdueCandidates = {}

	for _, senderId in ipairs(self.senderOrder) do
		local entry = self.notificationsBySender[senderId]
		if entry ~= nil then
			if entry.followUpState == FOLLOW_UP_ANSWERED then
				if now - (entry.answeredAtMs or now) >= self:GetFollowUpAnsweredVisibleMs() then
					answeredToRemove[#answeredToRemove + 1] = senderId
				end
			else
				local graceActive = entry.replyOpenedMs ~= nil
					and now - entry.replyOpenedMs < self:GetFollowUpReplyGraceMs()
				if entry.replyOpenedMs ~= nil and not graceActive then
					entry.replyOpenedMs = nil
					changed = true
				end
				local age = now - (entry.pendingSinceMs or entry.lastMessageMs or now)
				local nextState = FOLLOW_UP_PENDING
				if not graceActive and age >= self:GetFollowUpOverdueMs() then
					nextState = FOLLOW_UP_OVERDUE
				elseif not graceActive and age >= self:GetFollowUpWaitingMs() then
					nextState = FOLLOW_UP_WAITING
				end

				if entry.followUpState ~= nextState then
					entry.followUpState = nextState
					changed = true
				end
				if nextState == FOLLOW_UP_WAITING and (entry.reminderStage or 0) < 1 then
					entry.reminderStage = 1
				end

				if nextState == FOLLOW_UP_OVERDUE and (entry.reminderStage or 0) < 2 then
					overdueCandidates[#overdueCandidates + 1] = senderId
				end
			end
		end
	end

	for _, senderId in ipairs(answeredToRemove) do
		if RemoveSenderEntry(self, senderId) then
			changed = true
		end
	end

	if canSignalReminder and #overdueCandidates > 0 then
		local reminderSenderId = overdueCandidates[1]
		local oldestPendingSinceMs = nil
		for _, senderId in ipairs(overdueCandidates) do
			local entry = self.notificationsBySender[senderId]
			if entry ~= nil then
				entry.reminderStage = 2
				local pendingSinceMs = entry.pendingSinceMs or now
				if oldestPendingSinceMs == nil or pendingSinceMs < oldestPendingSinceMs then
					oldestPendingSinceMs = pendingSinceMs
					reminderSenderId = senderId
				end
			end
		end

		local reminderEntry = self.notificationsBySender[reminderSenderId]
		if reminderEntry ~= nil then
			self.latestReminderSenderId = reminderSenderId
			self.latestReminderRevision = reminderEntry.incomingRevision
			self:MoveSenderToFront(reminderSenderId)
			changed = true
		end
	end

	if changed then
		self:PersistWhisperRestore()
		self:RefreshNotifications()
	end

	return changed
end

function addon:OnChatMessageChannel(_, channelType, fromName, text, _, fromDisplayName)
	if channelType == CHAT_CHANNEL_WHISPER_SENT then
		self:MarkOutgoingReply(fromName, fromDisplayName)
		return
	end

	if channelType ~= CHAT_CHANNEL_WHISPER then
		return
	end

	local senderId = fromDisplayName
	if type(senderId) ~= "string" or senderId == "" then
		if type(fromName) == "string" and fromName ~= "" then
			senderId = zo_strformat("<<1>>", fromName)
		end
	end

	self:AddOrUpdateNotification(senderId, text, fromName, fromDisplayName)
end