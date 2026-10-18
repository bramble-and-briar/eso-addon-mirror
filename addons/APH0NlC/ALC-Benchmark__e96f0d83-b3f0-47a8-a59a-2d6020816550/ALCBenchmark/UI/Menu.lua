--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local Say, view, ShowSaved, MENU_GAP, Pad = AB.Say, AB.view, AB.ShowSaved, AB.MENU_GAP, AB.Pad
local Build, UI, NAME, ClampSeconds = AB.Build, AB.UI, AB.NAME, AB.ClampSeconds
local DEFAULT_SECONDS, ClampChurn, DEFAULT_CHURN_MB, History, Describe, Comparable = AB.DEFAULT_SECONDS, AB.ClampChurn, AB.DEFAULT_CHURN_MB, AB.History, AB.Describe, AB.Comparable
local Finish, MIN_SECONDS_CONSOLE, MIN_SECONDS_PC, StartAB, StartRun, PoolCapacityMB = AB.Finish, AB.MIN_SECONDS_CONSOLE, AB.MIN_SECONDS_PC, AB.StartAB, AB.StartRun, AB.PoolCapacityMB
local PAGES, PAGE_NAMES, StartAutoTravel, AnnounceTravel, StopAutoTravel = AB.PAGES, AB.PAGE_NAMES, AB.StartAutoTravel, AB.AnnounceTravel, AB.StopAutoTravel

local function Help()
	Say("/alcbench: show or hide the window; right-click it (or press the options button with a controller) to start tests and to show, compare, rename, delete or clear saved tests. /alcbench alc [seconds] [MB per second] [real] [reload]: Vanilla, every ALC cleanup method, and on PC Memory Garbage Collector and Shissu's LUA Memory when they are installed (needs at least one cleaner; each is held outside its own phases and cleans once in each of them, Shissu's LUA Memory through its /slm clean). /alcbench alconly [seconds] [MB per second] [real] [reload]: every ALC cleanup method, no Vanilla. /alcbench vanilla [seconds] [MB per second] [real] [reload]: the game on its own, twice (once ending in a loading screen, once without); needs ALC disabled or its Auto Lua Cleanup off, and holds every cleanup by ALC, LibAPH or the benchmark. /alcbench alconly pauses the game's own garbage collector while each phase measures. real: no test garbage, measures what your add-ons make. reload: adds a phase per method that ends with a /reloadui." .. (IsConsoleUI() and "" or " /alcbench setfps [10 to 1000 or uncapped]: cap the game's frame rate. /alcbenchbugreport: open the bug report copy box.") .. " /alcbench memory: show or hide Lua and pool memory on screen. /alcbench fill [MB]: make garbage now. Auto travel in the menu jumps to a random house (inside, outside or preview) whenever a loading screen is needed, never to a zone already used in that test. Same place (on by default): start inside a house you own and every loading screen is a trip to one house and back, so every phase is measured at home. In /alcbench alc and alconly, every phase starts with a /reloadui and 10 seconds for add-ons to settle, and ALC cleans once in each of its phases. /alcbench stop. /alcbench clear.")
end

local function ClearResults()
	if AB.test then return Say("Stop the running test first (/alcbench stop).") end
	AB.saved.history = {}
	view.shown, view.compared = nil, {}
	ShowSaved()
	Say("Results cleared.")
end

local ShowChoices

local function MenuEntries(choices)
	local entries = {}
	for _, choice in ipairs(choices) do
		local text = choice.danger and ("|cFF0000" .. choice.text .. "|r") or (choice.active and ("|c00FF00" .. choice.text .. "|r") or choice.text)
		if choice.disabled then text = choice.text .. " (" .. choice.disabled .. ")" end
		local entry = { text = text, onClick = choice.callback, enabled = not choice.disabled }
		if choice.checkbox then
			entry.checkbox, entry.checked, entry.onToggle = true, choice.checked == true, choice.toggle
			entry.onClick = function() entry.checked = not entry.checked choice.toggle(entry.checked) end
		end
		if choice.submenu then entry.submenu = function() return MenuEntries(choice.submenu()) end end
		entries[#entries + 1] = entry
	end
	return entries
end

local function PlaceMenu()
	if not (AB.win and LibAPH.PlaceContextMenuBeside) then return end
	LibAPH.PlaceContextMenuBeside(AB.win, { gap = MENU_GAP, belowGap = Pad.hint_below, aboveGap = Pad.hint_above })
end
AB.Help, AB.ClearResults = Help, ClearResults

local function HeadedEntries(heading, choices)
	local entries = { { text = heading, header = true } }
	for _, entry in ipairs(MenuEntries(choices)) do entries[#entries + 1] = entry end
	return entries
end

ShowChoices = function(heading, choices, again)
	Build()
	local rebuild = again and function() return HeadedEntries(heading, again()) end or nil
	LibAPH.ShowScrollableMenu(AB.win, HeadedEntries(heading, choices), { rebuild = rebuild })
	if Pad.focus then LibAPH.MoveContextMenuFocus(1) end
	Pad.Refresh()
	PlaceMenu()
end

local function ShowRecord(record, compared)
	view.shown, view.compared, view.blank = record, compared or {}, nil
	ShowSaved()
	UI.Show()
end

local text_dialogs = {}

local function AskText(spec)
	local focused = Pad.focus
	local was_visible = UI.IsShown()
	Pad.Stop()
	if was_visible then UI.Hide() end
	LibAPH.CloseContextMenu()
	local function ComeBack()
		if was_visible then UI.Show() end
		if focused then Pad.Start() end
	end
	if IsConsoleUI() or IsInGamepadPreferredMode() then
		LibAPH.ShowGamepadTextEntry({
			title = spec.title, prompt = spec.prompt, initialText = spec.initial, maxChars = spec.maxChars,
			onConfirm = spec.onConfirm,
			onClosed = ComeBack,
		})
		return
	end
	if not text_dialogs[spec.id] then
		text_dialogs[spec.id] = true
		ZO_Dialogs_RegisterCustomDialog(spec.id, {
			title = { text = spec.title },
			mainText = { text = spec.body },
			editBox = { maxInputCharacters = spec.maxChars },
			buttons = {
				{ text = SI_DIALOG_ACCEPT, callback = function(dialog) dialog.data.onConfirm(ZO_Dialogs_GetEditBoxText(dialog)) end },
				{ text = SI_DIALOG_CANCEL },
			},
			finishedCallback = function(dialog) if dialog.data and dialog.data.restore then dialog.data.restore() end end,
		})
	end
	ZO_Dialogs_ShowDialog(spec.id, { onConfirm = spec.onConfirm, restore = ComeBack }, { initialEditText = spec.initial })
end

local function RenameRecord(record, text)
	text = zo_strtrim(text or "")
	record.name = text ~= "" and text or nil
	if not AB.test then ShowSaved() end
end

local function AskRename(record)
	AskText({
		id = NAME .. "_Rename", title = "Rename test", body = "Leave it empty to show the date and time again.",
		prompt = "Name", initial = record.name or "", maxChars = 40,
		onConfirm = function(text) RenameRecord(record, text) end,
	})
end

local function AskNumber(id, heading, body, prompt, current, apply)
	AskText({
		id = id, title = heading, body = body, prompt = prompt, initial = tostring(current), maxChars = 8,
		onConfirm = function(text)
			local number = tonumber(zo_strtrim(text or ""))
			if not number then return Say("Not a number: " .. tostring(text)) end
			apply(number)
			zo_callLater(function() if UI.OpenMenu then UI.OpenMenu() end end, 200)
		end,
	})
end

local function MenuSeconds()
	return ClampSeconds(AB.saved.menu_seconds or DEFAULT_SECONDS)
end

local function MenuChurn()
	return ClampChurn(AB.saved.menu_churn or DEFAULT_CHURN_MB)
end

local function ChurnText(churn)
	return (string.format("%.2f", churn):gsub("0+$", ""):gsub("%.$", ""))
end

local function DeleteRecord(record)
	local history = History()
	for index = #history, 1, -1 do
		if history[index] == record then table.remove(history, index) end
	end
	if view.shown == record then view.shown, view.compared = nil, {} end
	for index = #view.compared, 1, -1 do
		if view.compared[index] == record then table.remove(view.compared, index) end
	end
	if not AB.test then ShowSaved() end
end

local function ConfirmDelete(record)
	zo_callLater(function()
		ShowChoices("Delete " .. Describe(record) .. "?", {
			{ text = "Yes, delete this test", danger = true, callback = function() DeleteRecord(record) end },
			{ text = "Cancel", callback = function() end },
		})
	end, 100)
end

local function ShowNothing()
	view.shown, view.compared, view.blank = nil, {}, true
	ShowSaved()
	UI.Show()
end

local function SavedTestChoices()
	local list = { { text = "Nothing", active = view.blank or nil, callback = ShowNothing } }
	for index, record in ipairs(History()) do
		local showing = record == view.shown
		list[#list + 1] = { text = Describe(record, index) .. (showing and " (showing)" or ""), active = showing or nil, submenu = function()
			local now = record == view.shown
			return {
				{ text = now and "Show (showing now)" or "Show", active = now or nil, callback = function() ShowRecord(record, nil) end },
				{ text = "Rename", callback = function() AskRename(record) end },
				{ text = "Delete", danger = true, callback = function() ConfirmDelete(record) end },
			}
		end }
	end
	return list
end

local function KindOf(record)
	return (record.kind == "run" or record.kind == "alc_only") and record.kind or "all"
end

local function CompareChoices()
	if view.blank then
		local list = { { text = "Nothing", active = true, callback = function() end } }
		for index, record in ipairs(History()) do
			list[#list + 1] = { text = Describe(record, index), checkbox = true, checked = false, toggle = function(on)
				if on then ShowRecord(record, {}) end
			end }
		end
		return list
	end
	local shown = view.shown or History()[1]
	local list = { { text = "Nothing", active = #view.compared == 0 or nil, callback = function() ShowRecord(shown, nil) end } }
	local picked = {}
	for _, record in ipairs(view.compared) do picked[record] = true end
	for index, record in ipairs(History()) do
		if record == shown then
			list[#list + 1] = { text = Describe(record, index) .. " (showing)", active = true, callback = function() end }
		else
			local ok, why = Comparable(shown, record)
			local comparing = picked[record] == true
			list[#list + 1] = { text = Describe(record, index) .. (comparing and " (comparing)" or ""), active = comparing or nil,
				disabled = not ok and why or nil, checkbox = true, checked = comparing, toggle = function(on)
					local kept = {}
					for _, other in ipairs(History()) do
						local same_side = KindOf(other) == KindOf(record)
						if other ~= shown and ((other == record and on) or (other ~= record and picked[other] and (not on or same_side))) then kept[#kept + 1] = other end
					end
					ShowRecord(shown, kept)
				end }
		end
	end
	return list
end

local function ConfirmClear()
	zo_callLater(function()
		ShowChoices("Clear all ALC Benchmark results?", {
			{ text = "Yes, clear the results", danger = true, callback = ClearResults },
			{ text = "Cancel", callback = function() end },
		})
	end, 100)
end

local function MainChoices()
	local choices = {}
	if AB.test then
		choices[#choices + 1] = { text = "Stop the test", callback = function() Finish(true) end }
	elseif AB.LOAD.run then
		choices[#choices + 1] = { text = "Stop the loading screen test", callback = function() AB.LOAD.Stop() end }
	else
		local opts = { real = UI.On("real_world"), reload = UI.On("reload_phases") }
		local least = IsConsoleUI() and MIN_SECONDS_CONSOLE or MIN_SECONDS_PC
		choices[#choices + 1] = { text = string.format("Length: %d s per phase", MenuSeconds()), callback = function()
			AskNumber(NAME .. "_Length", "Test length", string.format("Seconds each phase is measured (at least %d).", least), "Seconds", MenuSeconds(),
				function(number) AB.saved.menu_seconds = ClampSeconds(number) end)
		end }
		if not UI.On("real_world") and not AB.saved.advanced_test then
			choices[#choices + 1] = { text = "Extra garbage: " .. ChurnText(MenuChurn()) .. " MB/s", callback = function()
				AskNumber(NAME .. "_Churn", "Extra garbage", "MB of garbage the test makes every second while measuring (0 for none).", "MB/s", ChurnText(MenuChurn()),
					function(number) AB.saved.menu_churn = ClampChurn(number) end)
			end }
		end
		if not IsConsoleUI() then
			local cap = LibAPH.GetFpsCap()
			choices[#choices + 1] = { text = "Set FPS (|c00FF00" .. (cap and tostring(cap) or "uncapped") .. "|r)", callback = function()
				AskText({
					id = NAME .. "_Fps", title = "Set FPS",
					body = string.format("Frames per second to cap the game at (%d to %d), or uncapped.", LibAPH.FPS_CAP_MIN, LibAPH.FPS_CAP_MAX),
					prompt = "FPS", initial = cap and tostring(cap) or "uncapped", maxChars = 8,
					onConfirm = function(text)
						AB.GS.SetFps(text)
						zo_callLater(function() if UI.OpenMenu then UI.OpenMenu() end end, 200)
					end,
				})
			end }
		end
		if UI.CanContinue() then
			choices[#choices + 1] = { text = "Continue the cut-off test (from " .. tostring(AB.saved.cut.where) .. ")", callback = UI.Continue }
		end
		local alc_blocked = UI.AlcBlocked()
		local runs = {
			{ text = "ALL TEST", disabled = UI.AllBlocked(), callback = function() StartAB(MenuSeconds(), MenuChurn(), opts) end },
			{ text = "ALC ONLY TEST", disabled = alc_blocked, callback = function() StartAB(MenuSeconds(), MenuChurn(), opts, true) end },
		}
		if UI.VanillaBlocked() then
			runs[#runs + 1] = { text = "VANILLA ONLY TEST", disabled = "turn ALC off first", callback = function() end }
		else
			runs[#runs + 1] = { text = "VANILLA ONLY TEST", callback = function() StartRun(MenuSeconds(), MenuChurn(), opts) end }
		end
		runs[#runs + 1] = { text = "LOADING SCREEN TEST", submenu = AB.LOAD.MenuChoices }
		choices[#choices + 1] = { text = "Run Test", submenu = function() return runs end }
		if #History() > 0 then
			choices[#choices + 1] = { text = "Saved tests", submenu = SavedTestChoices }
			if #History() > 1 or (view.blank and #History() > 0) then choices[#choices + 1] = { text = "Compare Test", submenu = CompareChoices } end
			choices[#choices + 1] = { text = "Clear results", danger = true, callback = ConfirmClear }
		end
		if #AB.LOAD.Saved() > 0 then choices[#choices + 1] = { text = "Saved loading screen tests", submenu = AB.LOAD.SavedChoices } end
	end
	local advanced = {}
	if not AB.test then
		advanced[#advanced + 1] = { text = "Real world (no test garbage): " .. (UI.On("real_world") and "|c00FF00on|r" or "off"), callback = function()
			AB.saved.real_world = not UI.On("real_world")
			if AB.saved.real_world then AB.saved.menu_churn = 0 end
		end }
		advanced[#advanced + 1] = { text = "Reload phases: " .. (UI.On("reload_phases") and "|c00FF00on|r" or "off"), callback = function()
			AB.saved.reload_phases = not UI.On("reload_phases")
		end }
		if #AB.UsableCleaners() > 0 then
			advanced[#advanced + 1] = { text = "Force other cleaners to clean: " .. (AB.ForcingCleaners() and "|c00FF00on|r" or "off"), callback = function()
				AB.saved.force_cleaners = not AB.ForcingCleaners() or nil
			end }
		end
		if PoolCapacityMB() then
			advanced[#advanced + 1] = { text = "Low memory protection (reload before add-ons are disabled): " .. (AB.saved.memory_limit_stop ~= false and "|c00FF00on|r" or "off"), callback = function()
				AB.saved.memory_limit_stop = AB.saved.memory_limit_stop == false
			end }
		end
		advanced[#advanced + 1] = { text = "Advanced Test: " .. (AB.saved.advanced_test and "|c00FF00on|r" or "off"), callback = function()
			AB.saved.advanced_test = not AB.saved.advanced_test or nil
		end }
		if AB.saved.advanced_test and not UI.On("real_world") then
			advanced[#advanced + 1] = { text = "Fill: " .. ChurnText(MenuChurn()) .. " MB/s", callback = function()
				AskNumber(NAME .. "_Churn", "Fill", "MB of garbage the test makes every second while measuring, which the cleaners and the game can clean (0 for none).", "MB/s", ChurnText(MenuChurn()),
					function(number) AB.saved.menu_churn = ClampChurn(number) end)
			end }
			local hold_mb, hold_pool, hold_s = AB.FillHold()
			local hold_text = hold_pool and string.format("pool to %d MB", hold_pool) or string.format("%d MB", hold_mb)
			advanced[#advanced + 1] = { text = "Fill Hold: " .. hold_text, callback = function()
				if hold_pool then
					AskNumber(NAME .. "_HoldPool", "Fill Hold", "Fill the add-on pool to this many MB before each phase measures, and hold it (0 to 85).", "MB", hold_pool,
						function(number) AB.saved.fill_hold_pool = math.floor(zo_clamp(number, 0, 85)) end)
				else
					AskNumber(NAME .. "_HoldMB", "Fill Hold", "MB of memory held before each phase measures, which nothing can clean until it is let go (0 to 500).", "MB", hold_mb,
						function(number) AB.saved.fill_hold_mb = math.floor(zo_clamp(number, 0, 500)) end)
				end
			end }
			advanced[#advanced + 1] = { text = "Fill Hold time: " .. (hold_s and string.format("%d s", hold_s) or "until 10 s before the end"), callback = function()
				AskNumber(NAME .. "_HoldTime", "Fill Hold time", "Seconds the fill is held once a phase measures (0 holds it until 10 s before the phase ends).", "Seconds", hold_s or 0,
					function(number) AB.saved.fill_hold_s = number >= 1 and math.floor(number) or nil end)
			end }
		end
		advanced[#advanced + 1] = { text = "Simulated Actions (Inventory, Combat, Idle): " .. (AB.saved.simulate_player and "|c00FF00on|r" or "off"), callback = function()
			AB.saved.simulate_player = not AB.saved.simulate_player or nil
		end }
		advanced[#advanced + 1] = { text = "Same place (back home after each loading screen): " .. (UI.On("same_place") and "|c00FF00on|r" or "off"), callback = function()
			AB.saved.same_place = not UI.On("same_place")
		end }
	end
	local pages = {}
	for _, page in ipairs(PAGES) do
		pages[#pages + 1] = { text = PAGE_NAMES[page] .. (page == (view.page or "results") and " (showing)" or ""), callback = function() UI.SetPage(page) end }
	end
	advanced[#advanced + 1] = { text = "Auto travel to houses: " .. (UI.On("auto_travel") and "|c00FF00on|r" or "off"), callback = function()
		AB.saved.auto_travel = not UI.On("auto_travel")
		if not AB.test or AB.test.state ~= "await_travel" then return end
		if UI.On("auto_travel") then
			if not AB.test.auto_token and not StartAutoTravel() then AnnounceTravel() end
		elseif AB.test.auto_token then
			StopAutoTravel()
			AnnounceTravel()
		end
	end }
	advanced[#advanced + 1] = { text = "Memory display: " .. (AB.saved.memory_display and "|c00FF00on|r" or "off"), callback = AB.MEM.Toggle }
	advanced[#advanced + 1] = { text = "Controller button hints: " .. (UI.On("pad_hints") and "|c00FF00on|r" or "off"), callback = function()
		AB.saved.pad_hints = not UI.On("pad_hints")
		Pad.Refresh()
	end }
	advanced[#advanced + 1] = { text = "Test status under the compass: " .. (UI.On("status_line") and "|c00FF00on|r" or "off"), callback = function()
		AB.saved.status_line = not UI.On("status_line")
		if not AB.saved.status_line then UI.HideStatusLine() end
	end }
	choices[#choices + 1] = { text = "Advanced options", submenu = function() return advanced end }
	choices[#choices + 1] = { text = "Page: " .. PAGE_NAMES[view.page or "results"], submenu = function() return pages end }
	if view.page == "timeline" and UI.IsShown() then choices[#choices + 1] = { text = "Timeline: show or hide", submenu = function()
		local list = {}
		for _, entry in ipairs(UI.TIMELINE_KEYS) do
			local key = entry[1]
			list[#list + 1] = { text = entry[2], checkbox = true, checked = not UI.TimelineHidden(key), toggle = function(on)
				if on == UI.TimelineHidden(key) then UI.ToggleTimelineKey(key) end
			end }
		end
		return list
	end } end
	choices[#choices + 1] = { text = UI.IsShown() and "Close the window" or "Show the window", callback = function()
		if UI.IsShown() then UI.Hide() else ShowSaved() UI.Show() end
	end }
	return choices
end

AB.AskNumber, AB.ShowChoices = AskNumber, ShowChoices

function UI.OpenMenu()
	ShowChoices("ALC Benchmark", MainChoices(), MainChoices)
end
