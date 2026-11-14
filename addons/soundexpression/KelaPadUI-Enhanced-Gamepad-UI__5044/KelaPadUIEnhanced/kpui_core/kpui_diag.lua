-- Diagnostics: writes a structured snapshot through LibDebugLogger so it can be
-- read from SavedVariables/LibDebugLogger.lua on the gamepad UI. Every section
-- is pcall-wrapped: one missing API or bad quest must not abort the whole dump.

SLASH_COMMANDS["/keladiag"] = function()
	local L = KelaPadUI.log
	if not L and LibDebugLogger then
		L = LibDebugLogger:Create(KelaPadUI.name)
		KelaPadUI.log = L
	end
	if not L then
		d("KelaPadUI: LibDebugLogger is not loaded; /keladiag cannot write its log.")
		return
	end

	local function log(fmt, ...)
		local ok, message = pcall(string.format, fmt, ...)
		if ok then
			L:Info(message)
		else
			L:Error("FORMAT ERROR: %s | %s", tostring(fmt), tostring(message))
		end
	end

	local function section(name, fn)
		log("=== %s ===", name)
		local ok, err = pcall(fn)
		if not ok then
			L:Error("%s failed: %s", name, tostring(err))
		end
	end

	-- Formats an absolute reset boundary, and logs the stored vs freshly
	-- computed boundary so a jitter or source-disagreement wipe can be spotted.
	local function formatBoundary(seconds)
		if type(seconds) ~= "number" or seconds <= 0 then
			return tostring(seconds)
		end
		local ok, text = pcall(os.date, "!%Y-%m-%d %H:%M UTC", seconds)
		if ok and text then
			return text
		end
		return tostring(seconds)
	end

	local function LogDailyResetBounds(savedKey, state)
		local now = GetTimeStamp and GetTimeStamp() or 0
		local timedReset = nil
		if GetTimedActivityTypeResetTimeS and TIMED_ACTIVITY_TYPE_DAILY then
			local ok, resetTime = pcall(GetTimedActivityTypeResetTimeS, TIMED_ACTIVITY_TYPE_DAILY)
			if ok then
				timedReset = resetTime
			end
		end
		local remaining = GetTimeUntilNextDailyLoginRewardClaimS and GetTimeUntilNextDailyLoginRewardClaimS() or nil

		local learned = type(kpuiSavedVariables) == "table" and kpuiSavedVariables.dailyResetOffset or nil
		local learnedText = type(learned) == "number"
			and string.format("yes(%02d:%02d UTC)", math.floor(learned / 3600), math.floor((learned % 3600) / 60))
			or "no"

		local boundary = nil
		if remaining and remaining > 0 then
			boundary = math.floor((now + remaining) / 300 + 0.5) * 300
		elseif type(learned) == "number" then
			boundary = (math.floor((now - learned) / 86400) + 1) * 86400 + learned
		elseif type(timedReset) == "number" and timedReset > now then
			boundary = math.floor(timedReset / 300 + 0.5) * 300
		else
			boundary = (math.floor((now - 36000) / 86400) + 1) * 86400 + 36000
		end

		local stored = state and state.resetAt
		local delta = (type(stored) == "number" and type(boundary) == "number") and (boundary - stored) or nil
		local samePeriod = type(stored) == "number" and stored > now and stored <= now + 172800

		log("[%s] now=%s | storedResetAt=%s (%s) | freshBoundary=%s (%s) | delta=%s | samePeriod=%s",
			savedKey, tostring(now), tostring(stored), formatBoundary(stored),
			tostring(boundary), formatBoundary(boundary), tostring(delta), tostring(samePeriod))
		log("[%s] rawTimer=%s | timedActivityReset=%s | learnedOffset=%s",
			savedKey, tostring(remaining), tostring(timedReset), learnedText)
	end

	log("KelaPadUI diagnostics start | diag=2 | time=%s | gamepad=%s | api=%s",
		tostring(GetTimeString and GetTimeString() or "?"),
		tostring(IsInGamepadPreferredMode and IsInGamepadPreferredMode()),
		tostring(GetAPIVersion and GetAPIVersion()))

	section("environment", function()
		log("player=%s | level=%s | account=%s",
			tostring(GetUnitName and GetUnitName("player")),
			tostring(GetUnitLevel and GetUnitLevel("player")),
			tostring(GetDisplayName and GetDisplayName()))
		log("libDebugLogger=%s | libDebugLoggerApi=%s | addon=%s",
			tostring(LibDebugLogger ~= nil),
			tostring(LibDebugLogger and LibDebugLogger.GetAPIVersion and LibDebugLogger:GetAPIVersion()),
			tostring(KelaPadUI and KelaPadUI.name))
	end)

	section("feature settings", function()
		local features = {
			{ "dashboard", KELA_SETTING_PANEL_FEATURES_MAIN_MENU_DASHBOARD },
			{ "shortcuts", KELA_SETTING_PANEL_FEATURES_MAIN_MENU_SHORTCUTS },
			{ "dungeonFinder", KELA_SETTING_PANEL_FEATURES_DUNGEON_FINDER },
			{ "companion", KELA_SETTING_PANEL_FEATURES_COMPANION },
			{ "chatTools", KELA_SETTING_PANEL_FEATURES_CHAT_TOOLS },
			{ "mapRally", KELA_SETTING_PANEL_FEATURES_MAP_RALLY },
			{ "gamepadFilters", KELA_SETTING_PANEL_FEATURES_GAMEPAD_FILTERS },
			{ "antiquityLeads", KELA_SETTING_PANEL_FEATURES_ANTIQUITY_LEADS },
			{ "paJunk", KELA_SETTING_PANEL_FEATURES_PA_JUNK },
		}
		local parts = {}
		for _, feature in ipairs(features) do
			local name, settingId = feature[1], feature[2]
			local ok, enabled = pcall(KelaGetSetting_Bool, SETTING_TYPE_KELA, settingId)
			parts[#parts + 1] = string.format("%s=%s", name, ok and tostring(enabled) or "ERROR")
		end
		table.sort(parts)
		log("%s", table.concat(parts, " | "))
	end)

	section("dashboard state", function()
		local dashboard = Kela_MainMenuDashboard
		log("control=%s | hidden=%s | children=%s | mainMenu=%s | sceneShowing=%s",
			tostring(dashboard ~= nil),
			tostring(dashboard and dashboard:IsHidden()),
			tostring(dashboard and dashboard:GetNumChildren()),
			tostring(MAIN_MENU_GAMEPAD ~= nil),
			tostring(MAIN_MENU_GAMEPAD_SCENE and MAIN_MENU_GAMEPAD_SCENE:IsShowing()))
		log("setupFunction=%s | pledgeReportFunction=%s",
			tostring(type(KelaSetupMainMenuDashboard) == "function"),
			tostring(type(KelaGetPledgeReport) == "function"))

		if type(KelaGetPledgeReport) == "function" then
			local ok, report = pcall(KelaGetPledgeReport)
			if ok and type(report) == "table" then
				for i = 1, 3 do
					local pledge = report[i]
					if pledge then
						log("pledge%d|giver=%s|dungeon=%s|status=%s", i,
							tostring(pledge.giver), tostring(pledge.dungeon), tostring(pledge.status))
					end
				end
			else
				log("pledgeReport failed: %s", tostring(report))
			end
		end

		local function cooldown(cooldownType)
			if type(GetLFGCooldownTimeRemainingSeconds) ~= "function" or not cooldownType then
				return "n/a"
			end
			local ok, remaining = pcall(GetLFGCooldownTimeRemainingSeconds, cooldownType)
			return ok and tostring(remaining) or ("ERROR:" .. tostring(remaining))
		end
		log("lfgCooldownApi=%s | dungeon=%s | battleground=%s",
			tostring(type(GetLFGCooldownTimeRemainingSeconds) == "function"),
			cooldown(LFG_COOLDOWN_DUNGEON_REWARD_GRANTED),
			cooldown(LFG_COOLDOWN_BATTLEGROUND_REWARD_GRANTED))
		log("promotionalEventManager=%s | tamrielTomesManager=%s | eventAnnouncementsApi=%s",
			tostring(PROMOTIONAL_EVENT_MANAGER ~= nil),
			tostring(TAMRIEL_TOMES_MANAGER ~= nil),
			tostring(type(GetNumEventAnnouncements) == "function"))
	end)

	section("dashboard rows", function()
		local dashboard = Kela_MainMenuDashboard
		if not dashboard then
			log("Kela_MainMenuDashboard is nil")
			return
		end
		local title = dashboard:GetNamedChild("Title")
		log("title=%s", tostring(title and title:GetText()))
		local found = 0
		local function walk(control)
			if not control then
				return
			end
			local name = control:GetName()
			if name and string.find(name, "^KelaDashboardRow%d+$") then
				local label = control:GetNamedChild("Label")
				local value = control:GetNamedChild("Value")
				log("row|%s|label=%s|value=%s|hidden=%s",
					tostring(name),
					tostring(label and label:GetText()),
					tostring(value and value:GetText()),
					tostring(control:IsHidden()))
				found = found + 1
			end
			local count = control:GetNumChildren()
			for i = 1, count do
				walk(control:GetChild(i))
			end
		end
		walk(dashboard)
		log("rowsFound=%d", found)
	end)

	section("journal", function()
		local count = type(GetNumJournalQuests) == "function" and GetNumJournalQuests() or 0
		log("journalCount=%d", count)
		if count > 0 then
			log("journalInfoReturns=%s", tostring(select("#", GetJournalQuestInfo(1))))
		end
		for i = 1, count do
			local ok, err = pcall(function()
				local name, _, stepText, stepType, override, completed, tracked, level, _, questType = GetJournalQuestInfo(i)
				local id = GetJournalQuestId(i)
				log("J%d|name=%s|id=%s|jt=%s|jr=%s|completed=%s|apiComplete=%s|ending=%s|override=%s|stepType=%s|tracked=%s|level=%s|qt=%s|qr=%s|zoneStory=%s|zone=%s|has=%s",
					i,
					tostring(name),
					tostring(id),
					tostring(GetJournalQuestType(i)),
					tostring(GetJournalQuestRepeatType(i)),
					tostring(completed),
					tostring(GetJournalQuestIsComplete(i)),
					tostring(IsJournalQuestStepEnding(i, 1)),
					tostring(override),
					tostring(stepType),
					tostring(tracked),
					tostring(level),
					tostring(GetQuestType(id)),
					tostring(GetQuestRepeatableType(id)),
					tostring(GetJournalQuestZoneStoryZoneId(i)),
					tostring(GetQuestZoneId(id)),
					tostring(HasCompletedQuest(id)))
			end)
			if not ok then
				log("J%d failed: %s", i, tostring(err))
			end
		end
	end)

	section("journal conditions", function()
		local count = type(GetNumJournalQuests) == "function" and GetNumJournalQuests() or 0
		for i = 1, count do
			local ok, err = pcall(function()
				local name, _, stepText, stepType, override = GetJournalQuestInfo(i)
				local repeatType = GetJournalQuestRepeatType(i)
				local questType = GetJournalQuestType(i)
				local zoneStory = GetJournalQuestZoneStoryZoneId(i)
				if repeatType == QUEST_REPEAT_DAILY
					or questType == QUEST_TYPE_UNDAUNTED_PLEDGE
					or questType == QUEST_TYPE_CRAFTING
					or zoneStory == 1436 then
					log("C%d|name=%s|step=%s|stepType=%s|override=%s|ending=%s",
						i, tostring(name), tostring(stepText), tostring(stepType),
						tostring(override), tostring(IsJournalQuestStepEnding(i, 1)))
					local numConditions = GetJournalQuestNumConditions(i, 1) or 0
					for j = 1, numConditions do
						local text, current, max, isFail, isComplete, isShared, isVisible, conditionType = GetJournalQuestConditionInfo(i, 1, j)
						log("  c%d|text=%s|cur=%s|max=%s|fail=%s|complete=%s|shared=%s|visible=%s|type=%s",
							j, tostring(text), tostring(current), tostring(max), tostring(isFail),
							tostring(isComplete), tostring(isShared), tostring(isVisible), tostring(conditionType))
					end
				end
			end)
			if not ok then
				log("C%d failed: %s", i, tostring(err))
			end
		end
	end)

	section("completed daily archive", function()
		local questId = 0
		local total = 0
		local logged = 0
		local firstId
		while true do
			questId = GetNextCompletedQuestId(questId)
			if not questId or questId == 0 then
				break
			end
			if GetQuestRepeatableType(questId) == QUEST_REPEAT_DAILY then
				total = total + 1
				if not firstId then
					firstId = questId
				end
				if logged < 50 then
					logged = logged + 1
					local name, questType = GetCompletedQuestInfo(questId)
					log("DONE|id=%s|name=%s|type=%s|zone=%s|has=%s",
						tostring(questId), tostring(name), tostring(questType),
						tostring(GetQuestZoneId(questId)), tostring(HasCompletedQuest(questId)))
				end
			end
		end
		log("completedDailyCount=%d | logged=%d", total, logged)
		if firstId then
			log("completedInfoReturns=%s", tostring(select("#", GetCompletedQuestInfo(firstId))))
		end
	end)

	section("daily writ tracking", function()
		local all = type(kpuiSavedVariables) == "table" and kpuiSavedVariables.dailyWrits or nil
		local characterId = (GetCurrentCharacterId and GetCurrentCharacterId()) or "?"
		local state = type(all) == "table" and all[characterId] or nil

		LogDailyResetBounds("dailyWrits", state)
		log("savedTable=%s | character=%s | savedResetAt=%s",
			tostring(all ~= nil), tostring(characterId), tostring(state and state.resetAt))

		local done = {}
		if state and type(state.ids) == "table" then
			for id in pairs(state.ids) do
				done[#done + 1] = tostring(id)
			end
		end
		table.sort(done)
		log("doneToday=%d | ids=%s", #done, table.concat(done, ","))

		local ready = {}
		local count = type(GetNumJournalQuests) == "function" and GetNumJournalQuests() or 0
		for i = 1, count do
			if GetJournalQuestIsComplete(i)
				and GetJournalQuestType(i) == QUEST_TYPE_CRAFTING
				and GetJournalQuestRepeatType(i) == QUEST_REPEAT_DAILY then
				ready[#ready + 1] = tostring(GetJournalQuestId and GetJournalQuestId(i))
			end
		end
		table.sort(ready)
		log("readyInJournal=%d | ids=%s", #ready, table.concat(ready, ","))
		log("timeStamp=%s | secondsUntilDailyReset=%s",
			tostring(GetTimeStamp and GetTimeStamp()),
			tostring(GetTimeUntilNextDailyLoginRewardClaimS and GetTimeUntilNextDailyLoginRewardClaimS()))
	end)

	section("daily archive tracking", function()
		local all = type(kpuiSavedVariables) == "table" and kpuiSavedVariables.dailyArchive or nil
		local characterId = (GetCurrentCharacterId and GetCurrentCharacterId()) or "?"
		local state = type(all) == "table" and all[characterId] or nil

		LogDailyResetBounds("dailyArchive", state)

		local done = {}
		if state and type(state.ids) == "table" then
			for id in pairs(state.ids) do
				done[#done + 1] = tostring(id)
			end
		end
		table.sort(done)
		log("savedTable=%s | character=%s | doneToday=%d | ids=%s",
			tostring(all ~= nil), tostring(characterId), #done, table.concat(done, ","))

		local ready = {}
		local count = type(GetNumJournalQuests) == "function" and GetNumJournalQuests() or 0
		for i = 1, count do
			local _, _, _, _, _, completed, _, _, _, questType = GetJournalQuestInfo(i)
			if completed and questType ~= QUEST_TYPE_UNDAUNTED_PLEDGE
				and GetJournalQuestRepeatType(i) == QUEST_REPEAT_DAILY
				and GetJournalQuestZoneStoryZoneId(i) == 1436 then
				ready[#ready + 1] = tostring(GetJournalQuestId and GetJournalQuestId(i))
			end
		end
		table.sort(ready)
		log("readyInJournal=%d | ids=%s", #ready, table.concat(ready, ","))
	end)

	section("daily pledge tracking", function()
		local all = type(kpuiSavedVariables) == "table" and kpuiSavedVariables.dailyPledges or nil
		local characterId = (GetCurrentCharacterId and GetCurrentCharacterId()) or "?"
		local state = type(all) == "table" and all[characterId] or nil

		LogDailyResetBounds("dailyPledges", state)

		local done = {}
		if state and type(state.ids) == "table" then
			for dungeon in pairs(state.ids) do
				done[#done + 1] = tostring(dungeon)
			end
		end
		table.sort(done)
		log("savedTable=%s | character=%s | completeToday=%d | dungeons=%s",
			tostring(all ~= nil), tostring(characterId), #done, table.concat(done, ","))

		local report = KelaGetPledgeReport and KelaGetPledgeReport(true) or {}
		for _, entry in ipairs(report) do
			local saved = state and type(state.ids) == "table" and state.ids[entry.dungeon]
			log("pledge=%s | giver=%s | complete=%s", tostring(entry.dungeon), tostring(entry.giver), tostring(saved ~= nil))
		end

		local count = type(GetNumJournalQuests) == "function" and GetNumJournalQuests() or 0
		for i = 1, count do
			local name, _, _, _, override, completed, _, _, _, questType = GetJournalQuestInfo(i)
			if questType == QUEST_TYPE_UNDAUNTED_PLEDGE then
				log("journalPledge=%s | completed=%s | override=%s",
					tostring(name), tostring(completed), tostring(override))
			end
		end
	end)

	section("recent warnings and errors", function()
		local entries = LibDebugLogger and LibDebugLogger:GetLog()
		if not entries then
			log("LibDebugLogger log unavailable")
			return
		end
		local found = 0
		for i = #entries, 1, -1 do
			local entry = entries[i]
			local level = entry and entry[LibDebugLogger.ENTRY_LEVEL_INDEX]
			if level == LibDebugLogger.LOG_LEVEL_WARNING or level == LibDebugLogger.LOG_LEVEL_ERROR then
				log("%s|%s|%s",
					tostring(entry[LibDebugLogger.ENTRY_FORMATTED_TIME_INDEX]),
					tostring(entry[LibDebugLogger.ENTRY_TAG_INDEX]),
					tostring(entry[LibDebugLogger.ENTRY_MESSAGE_INDEX]))
				found = found + 1
				if found >= 20 then
					break
				end
			end
		end
		if found == 0 then
			log("none")
		end
	end)

	section("api checks", function()
		local apis = {
			"GetNumJournalQuests", "GetJournalQuestInfo", "GetJournalQuestId",
			"GetJournalQuestIsComplete", "GetJournalQuestRepeatType", "GetJournalQuestType",
			"GetJournalQuestZoneStoryZoneId", "GetJournalQuestNumConditions",
			"GetJournalQuestConditionInfo", "IsJournalQuestStepEnding",
			"GetNextCompletedQuestId", "GetCompletedQuestInfo", "GetQuestRepeatableType",
			"GetQuestType", "GetQuestZoneId", "HasCompletedQuest",
			"GetCurrentCharacterId", "GetTimeStamp", "GetTimeUntilNextDailyLoginRewardClaimS",
			"GetTimedActivityTypeResetTimeS",
			"KelaGetPledgeReport", "GetLFGCooldownTimeRemainingSeconds",
			"GetNumEventAnnouncements", "GetEventAnnouncementNameByIndex",
		}
		local missing = {}
		for _, name in ipairs(apis) do
			if type(_G[name]) ~= "function" then
				missing[#missing + 1] = name
			end
		end
		log("missing=%s", #missing > 0 and table.concat(missing, ",") or "none")
	end)

	log("KelaPadUI diagnostics end")
	d("KelaPadUI diagnostics written to LibDebugLogger.")
end
