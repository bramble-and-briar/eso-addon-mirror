-- FindMyStuff_Gamepad.lua
-- Console / gamepad front end, built the same way as Better Group Finder
-- (Console): a full-screen parametric list like the game's own menus, with
-- page history (B goes back), tooltips on the left, and keybinds:
--   A = row action, X = row alternate, Y = page action, R3 = main page, B = back.
-- Ways to open it: Main Menu > Find My Stuff, /fms, the keybind, or L3 on the
-- guild store (which opens the trader filter keyboard without leaving the store).

FindMyStuff = FindMyStuff or {}

local GP = {}
FindMyStuff.GP = GP

local SCENE_NAME = "FindMyStuffGamepadScene"
local TEMPLATE = "ZO_GamepadMenuEntryTemplate"
local HEADER_TEMPLATE = "ZO_GamepadMenuEntryHeaderTemplate"
local TEXT_DIALOG = "FINDMYSTUFF_TEXT_INPUT"
local PREFIX = "|cFF7700FindMyStuff:|r "

local function Muted(text) return "|caaaaaa" .. tostring(text) .. "|r" end
local function Accent(text) return "|c4FC3F7" .. tostring(text) .. "|r" end
local function OnOff(b) return b and "|c7CFC00On|r" or Muted("Off") end

GP.text = {items = "", leads = ""}
-- dropdown choices on the Leads page (indexes into FindMyStuff.LeadTypeOptions / LeadShowOptions)
GP.leadChoice = {type = 1, show = 1}

---------------------------------------------------------------------------
-- Text entry (virtual keyboard) dialog, optionally with dropdowns
---------------------------------------------------------------------------
-- The entry list is rebuilt every time the dialog opens, so the same dialog
-- serves a plain text prompt and the lead search (text + Look for + Show).
local pending = nil
local dialogInfo = nil

local function DialogControl()
	if ZO_GenericGamepadDialog_GetControl then
		return ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
	end
end

local function TextFieldEntry()
	return {
		template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
		templateData = {
			textChangedCallback = function(control)
				if pending then pending.text = control:GetText() end
			end,
			setup = function(control, data, selected)
				control.highlight:SetHidden(not selected)
				local edit = control.editBoxControl
				edit.textChangedCallback = data.textChangedCallback
				if pending then
					-- also runs when a dropdown change rebuilds the list, so
					-- always put the typed text back
					edit:SetMaxInputChars(pending.maxChars or 200)
					local p = pending
					local function Fill()
						if pending ~= p or edit:HasFocus() then return end
						if edit:GetText() ~= (p.text or "") then edit:SetText(p.text or "") end
					end
					Fill()
					-- the dialog can clear the box while it opens; fill it again after
					zo_callLater(Fill, 50)
				end
			end,
			callback = function(dialog)
				local target = dialog.entryList:GetTargetControl()
				local edit = target and target.editBoxControl
				if edit then
					if pending and edit:GetText() ~= (pending.text or "") then edit:SetText(pending.text or "") end
					edit:TakeFocus()
				end
			end,
		},
	}
end

-- Dropdowns are drawn inline with plain menu rows (the same template as the
-- Done row): "Look for: Mythic leads  [+]". A opens it, listing the choices
-- right under it; A on a choice picks it and closes the list again.
local BuildDialogList -- forward declaration

local function Report(what, err)
	d(PREFIX .. what .. ": " .. tostring(err))
end

-- Redraws the dialog's rows (after a dropdown opens, closes or changes)
local function RefreshDialog(dialog, selectKey)
	if not pending or not dialogInfo then return end
	dialogInfo.parametricList = BuildDialogList()
	dialog = dialog or DialogControl()
	local ok, err = false, "no dialog"
	if dialog and ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList then
		ok, err = pcall(ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList, dialog)
	end
	if ok then
		-- keep the cursor on the dropdown that was used
		if selectKey and dialog.entryList then
			for i, entry in ipairs(dialogInfo.parametricList) do
				if entry.fmsKey == selectKey then
					pcall(dialog.entryList.SetSelectedIndexWithoutAnimation, dialog.entryList, i)
					break
				end
			end
		end
		return
	end
	-- fallback: close and reopen the dialog with the new rows
	local p = pending
	pcall(ZO_Dialogs_ReleaseDialog, TEXT_DIALOG)
	pending = p
	zo_callLater(function()
		if pending ~= p then return end
		local shown, showErr = pcall(ZO_Dialogs_ShowGamepadDialog, TEXT_DIALOG, {}, p.showParams)
		if not shown then
			pending = nil
			Report("Couldn't reopen the dialog", showErr)
		end
	end, 50)
end

local function MenuRow(text, callback, key)
	return {
		fmsKey = key,
		template = TEMPLATE,
		templateData = {
			text = text,
			setup = ZO_SharedGamepadEntry_OnSetup,
			callback = function(dialog)
				local ok, err = pcall(callback, dialog)
				if not ok then Report("Dialog error", err) end
			end,
		},
	}
end

-- Adds a dropdown's rows to list. dd = { key, header, options, visible(choice)? }
local function AddDropdownRows(list, dd)
	if dd.visible and not dd.visible(pending.choice) then return end
	local selected = pending.choice[dd.key] or 1
	local option = dd.options[selected] or dd.options[1]
	local isOpen = pending.openKey == dd.key
	list[#list + 1] = MenuRow(dd.header .. ": |c4FC3F7" .. option.name .. "|r  " .. (isOpen and "[-]" or "[+]"),
		function(dialog)
			pending.openKey = isOpen and nil or dd.key
			RefreshDialog(dialog, dd.key)
		end, dd.key)
	if isOpen then
		for i, o in ipairs(dd.options) do
			local mark = (i == selected) and "|c7CFC00>|r " or "    "
			list[#list + 1] = MenuRow(mark .. o.name, function(dialog)
				pending.choice[dd.key] = i
				pending.openKey = nil
				RefreshDialog(dialog, dd.key)
			end)
		end
	end
end

local function DoneEntry(text)
	return {
		template = TEMPLATE,
		templateData = {
			text = text or "Done",
			setup = ZO_SharedGamepadEntry_OnSetup,
			callback = function()
				local p = pending
				pending = nil
				ZO_Dialogs_ReleaseDialogOnButtonPress(TEXT_DIALOG)
				if p and p.onDone then
					local ok, err = pcall(p.onDone, p.text or "", p.choice)
					if not ok then Report("Search failed", err) end
				end
			end,
		},
	}
end

BuildDialogList = function()
	local list = { TextFieldEntry() }
	for _, dd in ipairs(pending.dropdowns or {}) do
		AddDropdownRows(list, dd)
	end
	list[#list + 1] = DoneEntry(pending.doneText)
	return list
end

local function RegisterTextDialog()
	dialogInfo = {
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
		blockDialogReleaseOnPress = true,
		setup = function(dialog) dialog:setupFunc() end,
		title = { text = "<<1>>" },
		mainText = { text = "<<1>>" },
		parametricList = { TextFieldEntry(), DoneEntry() },
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local data = dialog.entryList:GetTargetData()
					if data and data.callback then data.callback(dialog) end
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = SI_DIALOG_CANCEL,
				callback = function()
					pending = nil
					ZO_Dialogs_ReleaseDialogOnButtonPress(TEXT_DIALOG)
				end,
			},
		},
	}
	ZO_Dialogs_RegisterCustomDialog(TEXT_DIALOG, dialogInfo)
end

-- opts = { title, hint, text, maxChars, doneText,
--          dropdowns = {{ key, header, options, visible(choice)? }},
--          choice = { key = index }, onDone(text, choice) }
function GP:PromptText(opts)
	if not dialogInfo then
		d(PREFIX .. "Text entry is not available.")
		return
	end
	pending = {
		text = opts.text or "",
		maxChars = opts.maxChars,
		doneText = opts.doneText,
		dropdowns = opts.dropdowns,
		choice = {},
		showParams = {
			titleParams = { opts.title or "Find My Stuff" },
			mainTextParams = { opts.hint or "" },
		},
		onDone = function(text, choice)
			opts.onDone(text, choice)
			self:Rebuild(true)
		end,
	}
	for k, v in pairs(opts.choice or {}) do pending.choice[k] = v end
	for _, dd in ipairs(opts.dropdowns or {}) do
		pending.choice[dd.key] = pending.choice[dd.key] or 1
	end

	local built, buildErr = pcall(function() dialogInfo.parametricList = BuildDialogList() end)
	if not built then
		pending = nil
		Report("Couldn't build the dialog", buildErr)
		return
	end
	local ok, err = pcall(ZO_Dialogs_ShowGamepadDialog, TEXT_DIALOG, {}, pending.showParams)
	if not ok then
		pending = nil
		Report("Text entry is not available", err)
	end
end

-- Look for / Show dropdowns for the trader search
local function TraderDropdowns()
	return {
		{ key = "type", header = "Look for", options = FindMyStuff.TraderTypeOptions },
		{ key = "show", header = "Show", options = FindMyStuff.LeadShowOptions,
			visible = function(choice)
				local t = FindMyStuff.TraderTypeOptions[choice.type or 1]
				return t and t.lead
			end },
	}
end

local function LeadDropdowns()
	return {
		{ key = "type", header = "Look for", options = FindMyStuff.LeadTypeOptions },
		{ key = "show", header = "Show", options = FindMyStuff.LeadShowOptions },
	}
end

-- Trader filter dialog with the dropdowns (Guild Traders page and L3 in the store)
GP.traderChoice = { type = 1, show = 1 }
GP.traderText = ""
function GP:PromptTraderSearch(choice)
	local tab = FindMyStuff.GetTabInfo("traders")
	if choice then self.traderChoice = choice end
	local text = FindMyStuff.IsTraderLeadSearch() and self.traderText or FindMyStuff.GetTraderFilterText()
	self:PromptText({
		title = "Guild Trader Filter", hint = tab.hint, text = text,
		dropdowns = TraderDropdowns(), choice = self.traderChoice, doneText = "Scan Guild Traders",
		onDone = function(t, picked)
			self.traderChoice = { type = picked.type or 1, show = picked.show or 1 }
			self.traderText = t
			FindMyStuff.RunTraderSearch(t, FindMyStuff.TraderTypeOptions[self.traderChoice.type],
				FindMyStuff.LeadShowOptions[self.traderChoice.show])
		end,
	})
end

---------------------------------------------------------------------------
-- Screen class
---------------------------------------------------------------------------
local Screen = ZO_Gamepad_ParametricList_Screen and ZO_Gamepad_ParametricList_Screen:Subclass() or nil

if Screen then
	function Screen:Initialize(control, scene)
		self.headerData = { titleText = "Find My Stuff" }
		ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, scene)
	end

	function Screen:SetupList(list)
		list:AddDataTemplate(TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
		list:AddDataTemplateWithHeader(TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, HEADER_TEMPLATE)
		list:SetOnSelectedDataChangedCallback(function(_, data) GP:OnSelectionChanged(data) end)
	end

	function Screen:PerformUpdate()
		self.dirty = false
		GP:Rebuild(true)
	end

	function Screen:InitializeKeybindStripDescriptors()
		self.keybindStripDescriptor = {
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
			{
				name = function() local r = GP:SelectedRow() return r and r.actionText or GetString(SI_GAMEPAD_SELECT_OPTION) end,
				keybind = "UI_SHORTCUT_PRIMARY",
				visible = function() local r = GP:SelectedRow() return r ~= nil and r.action ~= nil end,
				enabled = function() local r = GP:SelectedRow() return r ~= nil and r.enabled ~= false end,
				callback = function() GP:RunRow("action") end,
			},
			{
				name = function() local r = GP:SelectedRow() return r and r.altText or "" end,
				keybind = "UI_SHORTCUT_SECONDARY",
				visible = function() local r = GP:SelectedRow() return r ~= nil and r.alt ~= nil end,
				callback = function() GP:RunRow("alt") end,
			},
			{
				name = function() local p = GP.pageInfo return p and p.tertiary and p.tertiary.text or "" end,
				keybind = "UI_SHORTCUT_TERTIARY",
				visible = function() local p = GP.pageInfo return p ~= nil and p.tertiary ~= nil end,
				callback = function()
					local p = GP.pageInfo
					if p and p.tertiary then p.tertiary.fn() GP:Rebuild(true) end
				end,
			},
			{
				name = "Main Menu",
				keybind = "UI_SHORTCUT_RIGHT_STICK",
				visible = function() return GP.page ~= "main" end,
				callback = function() GP:GoMain() end,
			},
		}
		ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function() GP:Back() end)
	end

	function Screen:OnHide()
		if ZO_Gamepad_ParametricList_Screen.OnHide then ZO_Gamepad_ParametricList_Screen.OnHide(self) end
		GP:ClearTooltips()
	end
end

---------------------------------------------------------------------------
-- Creation, navigation
---------------------------------------------------------------------------
GP.page = "main"
GP.args = nil
GP.stack = {}

function GP:Create()
	if self.screen or not Screen then return self.screen end
	local ok, err = pcall(function()
		local control = WINDOW_MANAGER:CreateControlFromVirtual("FindMyStuffGamepadTopLevel", GuiRoot, "FindMyStuffGamepadTemplate")
		local fragment = ZO_FadeSceneFragment:New(control)
		local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
		scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
		scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
		scene:AddFragment(FRAME_EMOTE_FRAGMENT_SYSTEM)
		scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
		scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
		scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
		scene:AddFragment(fragment)
		self.scene = scene
		self.screen = Screen:New(control, scene)
	end)
	if not ok then
		d(PREFIX .. "Could not create the gamepad screen: " .. tostring(err))
		self.screen, self.scene = nil, nil
	end
	return self.screen
end

function GP:IsShowing()
	return self.scene ~= nil and SCENE_MANAGER:IsShowing(SCENE_NAME)
end

function GP:Show(page, args)
	if not self:Create() then return false end
	self.stack = {}
	self.page = (page and self.pages[page]) and page or "main"
	self.args = args
	if self:IsShowing() then
		self:Rebuild(false)
	else
		SCENE_MANAGER:Push(SCENE_NAME)
	end
	return true
end

function GP:Close()
	if self:IsShowing() then SCENE_MANAGER:HideCurrentScene() end
end

function GP:Open(page, args)
	local list = self.screen and self.screen:GetMainList()
	self.stack[#self.stack + 1] = { page = self.page, args = self.args, index = list and list:GetSelectedIndex() }
	self.page = page
	self.args = args
	self:Rebuild(false)
end

function GP:Back()
	local prev = table.remove(self.stack)
	if not prev then
		self:Close()
		return
	end
	self.page = prev.page
	self.args = prev.args
	self:Rebuild(false, prev.index)
end

function GP:GoMain()
	self.stack = {}
	self.page = "main"
	self.args = nil
	self:Rebuild(false)
end

function GP:SelectedRow()
	local list = self.screen and self.screen:GetMainList()
	local data = list and list:GetTargetData()
	return data and data.fmsRow or nil
end

function GP:RunRow(which)
	local row = self:SelectedRow()
	if not row or not row[which] or (which == "action" and row.enabled == false) then return end
	local before = self.rebuildCount
	local ok, err = pcall(row[which])
	if not ok then d(PREFIX .. tostring(err)) end
	if self:IsShowing() and self.rebuildCount == before then
		self:Rebuild(true)
	end
end

function GP:ClearTooltips()
	if not GAMEPAD_TOOLTIPS then return end
	pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP)
	pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_RIGHT_TOOLTIP)
end

local function LayoutText(tooltipType, title, body)
	local ok = pcall(GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip, GAMEPAD_TOOLTIPS, tooltipType, title, body)
	if not ok then pcall(GAMEPAD_TOOLTIPS.LayoutSettingTooltip, GAMEPAD_TOOLTIPS, tooltipType, title .. "\n\n" .. body, "") end
end

function GP:OnSelectionChanged(data)
	local row = data and data.fmsRow
	if GAMEPAD_TOOLTIPS then
		self:ClearTooltips()
		if row and row.link and row.link ~= "" then
			-- item tooltip on the left, our details on the right
			pcall(GAMEPAD_TOOLTIPS.LayoutItem, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP, row.link)
			if row.tip then LayoutText(GAMEPAD_RIGHT_TOOLTIP, row.tip[1] or "", row.tip[2] or "") end
		elseif row and row.tip then
			LayoutText(GAMEPAD_LEFT_TOOLTIP, row.tip[1] or "", row.tip[2] or "")
		end
	end
	if self.screen and self.screen.keybindStripDescriptor and KEYBIND_STRIP then
		KEYBIND_STRIP:UpdateKeybindButtonGroup(self.screen.keybindStripDescriptor)
	end
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
-- A page builder returns { title, rows = {...}, tertiary = { text, fn } }.
-- Row: { text, header, icon, link, tip = { title, body }, action, actionText,
--        alt, altText, enabled }
GP.pages = {}

function GP:Rebuild(keepSelection, forceIndex)
	local screen = self.screen
	if not screen or not self:IsShowing() then return end
	local list = screen:GetMainList()
	local oldIndex = keepSelection and list:GetSelectedIndex() or nil
	self.rebuildCount = (self.rebuildCount or 0) + 1

	local builder = self.pages[self.page] or self.pages.main
	local ok, info = pcall(builder, self, self.args)
	if not ok then
		d(PREFIX .. "Page error: " .. tostring(info))
		info = { title = "Error", rows = { { text = "Something went wrong. Press B to go back.", tip = { "Error", tostring(info) } } } }
	end
	self.pageInfo = info

	list:Clear()
	for _, row in ipairs(info.rows or {}) do
		local data = ZO_GamepadEntryData:New(row.text or "", row.icon)
		if row.icon and data.SetIconTintOnSelection then data:SetIconTintOnSelection(true) end
		data.fmsRow = row
		if data.SetEnabled then data:SetEnabled(row.enabled ~= false) end
		if row.header then
			data:SetHeader(row.header)
			list:AddEntryWithHeader(TEMPLATE, data)
		else
			list:AddEntry(TEMPLATE, data)
		end
	end
	list:Commit()

	local target = forceIndex or oldIndex
	if target and target > 0 and list:GetNumItems() > 0 then
		list:SetSelectedIndexWithoutAnimation(math.min(target, list:GetNumItems()), true, false)
	end

	ZO_ClearTable(screen.headerData)
	screen.headerData.titleText = info.title or "Find My Stuff"
	if info.count then
		screen.headerData.data1HeaderText = "Results"
		screen.headerData.data1Text = tostring(info.count)
	end
	if info.data2 then
		screen.headerData.data2HeaderText = info.data2[1]
		screen.headerData.data2Text = info.data2[2]
	end
	if screen.header then ZO_GamepadGenericHeader_RefreshData(screen.header, screen.headerData) end

	self:OnSelectionChanged(list:GetTargetData())
end

-- Turns search rows from the core into gamepad rows
local function ResultRows(rows, header, emptyText)
	local out = {}
	for i, r in ipairs(rows or {}) do
		out[#out + 1] = {
			header = i == 1 and header or nil,
			text = r.title or r.line or "",
			link = r.link,
			tip = { zo_strformat("<<1>>", r.title or ""), r.detail or "" },
		}
	end
	if #out == 0 and emptyText then
		out[1] = { header = header, text = Muted(emptyText) }
	end
	return out
end

local function Append(rows, more)
	for _, r in ipairs(more) do rows[#rows + 1] = r end
	return rows
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local P = GP.pages

function P.main(self)
	local rows = {}
	rows[#rows + 1] = { header = "Find", text = "My Items",
		tip = { "My Items", "Search every character's bags, bank and craft bag for an item." },
		action = function() self:Open("items") end }
	rows[#rows + 1] = { text = "Guild Traders",
		tip = { "Guild Traders", "Filter guild store listings by name, trait, quality, price and unknown recipes / motifs. Open a guild store first, or press L3 while you're in one." },
		action = function() self:Open("traders") end }
	rows[#rows + 1] = { text = "Antiquity Leads",
		tip = { "Antiquity Leads", "Search every lead in the game by name, set or zone and see which ones you hold." },
		action = function() self:Open("leads") end }
	rows[#rows + 1] = { header = "Settings", text = "Settings",
		tip = { "Settings", "Login message, automatic rescans, trader pages and chat output." },
		actionText = "Open", action = function() self:Open("settings") end }
	return { title = "Find My Stuff", rows = rows }
end

function P.items(self)
	local tab = FindMyStuff.GetTabInfo("items")
	local text = self.text.items
	local rows = {}
	rows[#rows + 1] = { header = "Search", text = Accent("Search: ") .. (text ~= "" and text or Muted("press A to type")),
		tip = { tab.name, tab.hint }, actionText = "Type",
		action = function()
			self:PromptText({ title = "Find an Item", hint = tab.hint, text = text,
				onDone = function(t) self.text.items = t end })
		end,
		altText = text ~= "" and "Clear" or nil, alt = text ~= "" and function() self.text.items = "" end or nil }
	local results, status = FindMyStuff.GetTabRows("items", text)
	Append(rows, ResultRows(results, status and zo_strformat("<<1>>", status) or "Results", text ~= "" and "Nothing found." or nil))
	return { title = tab.name, rows = rows, count = text ~= "" and #results or nil,
		tertiary = { text = "Rescan Bags", fn = function()
			FindMyStuff.ScanInventory()
			d(PREFIX .. "Inventory rescanned.")
		end } }
end

function P.traders(self)
	local tab = FindMyStuff.GetTabInfo("traders")
	local filterText = FindMyStuff.GetTraderFilterText()
	local active = FindMyStuff.IsTraderFilterActive()
	local rows = {}
	rows[#rows + 1] = { header = "Filter", text = Accent("Filter: ") .. (filterText ~= "" and filterText or Muted(active and "everything" or "press A to set")),
		tip = { tab.name, tab.hint .. "\n\nYou can also press L3 in the guild store to set the filter without leaving it." },
		actionText = active and "Change & Rescan" or "Set & Scan",
		action = function() self:PromptTraderSearch() end,
		altText = active and "Stop" or nil, alt = active and function() FindMyStuff.StopTrader() end or nil }
	local tc = self.traderChoice
	local typeOption = FindMyStuff.TraderTypeOptions[tc.type] or FindMyStuff.TraderTypeOptions[1]
	local showOption = FindMyStuff.LeadShowOptions[tc.show] or FindMyStuff.LeadShowOptions[1]
	rows[#rows + 1] = { text = "Look for: " .. Accent(typeOption.name)
			.. (typeOption.lead and ("   Show: " .. Accent(showOption.name)) or ""),
		tip = { "Look for", "Choose Items, All leads or Mythic leads, and for leads whether to show ones you have, are missing or have never found. Words in the filter then match the item, mythic, antiquity, set or zone." },
		actionText = "Change", action = function() self:PromptTraderSearch() end }
	rows[#rows + 1] = { header = "Leads in Traders", text = "Search Mythic Leads",
		tip = { "Mythic Leads", "Scans the guild store for leads to any mythic item. Pick a category in the store first if you want to narrow it down." },
		actionText = "Scan", action = function() FindMyStuff.StartTraderLeadSearch("mythic") end,
		altText = "Missing Only", alt = function() FindMyStuff.StartTraderLeadSearch("mythic missing") end }
	rows[#rows + 1] = { text = "Search Leads by Item",
		tip = { "Leads by Item", "Type an item, mythic, antiquity, set or zone (e.g. ring of the wild hunt), pick from the dropdowns, and scan the guild store for its leads." },
		actionText = "Type & Scan",
		action = function()
			local t = self.traderChoice
			self:PromptTraderSearch({ type = FindMyStuff.TraderTypeOptions[t.type].lead and t.type or 2, show = t.show })
		end }
	rows[#rows + 1] = { header = "Status", text = Muted(FindMyStuff.GetTraderStatus()),
		tip = { "Status", FindMyStuff.GetTraderStatus() } }
	local results = FindMyStuff.GetTraderRows()
	Append(rows, ResultRows(results, "Matches", "No matches yet."))
	return { title = tab.name, rows = rows, count = #results }
end

function P.leads(self)
	local tab = FindMyStuff.GetTabInfo("leads")
	local text = self.text.leads
	local lc = self.leadChoice
	local typeOption = FindMyStuff.LeadTypeOptions[lc.type] or FindMyStuff.LeadTypeOptions[1]
	local showOption = FindMyStuff.LeadShowOptions[lc.show] or FindMyStuff.LeadShowOptions[1]
	local function OpenDialog()
		self:PromptText({ title = "Search Leads", hint = tab.hint, text = text,
			dropdowns = LeadDropdowns(), choice = self.leadChoice,
			onDone = function(t, picked)
				self.text.leads = t
				self.leadChoice = { type = picked.type or 1, show = picked.show or 1 }
			end })
	end
	local rows = {}
	rows[#rows + 1] = { header = "Search", text = Accent("Search: ") .. (text ~= "" and text or Muted("all leads")),
		tip = { tab.name, tab.hint }, actionText = "Type", action = OpenDialog,
		altText = text ~= "" and "Clear" or nil, alt = text ~= "" and function() self.text.leads = "" end or nil }
	rows[#rows + 1] = { text = "Look for: " .. Accent(typeOption.name) .. "   Show: " .. Accent(showOption.name),
		tip = { "Look for / Show", "Choose all leads or only mythic ones, and whether to list leads you have, are missing, or have never dug up." },
		actionText = "Change", action = OpenDialog }
	local query = FindMyStuff.BuildLeadQuery(text, typeOption, showOption)
	rows[#rows + 1] = { text = "Find these in Guild Traders",
		tip = { "Find in Guild Traders", "Scans the guild store for the leads listed below (same search and Show setting). Open a guild store first, or set it now and it starts when you open one." },
		actionText = "Scan", action = function()
			if FindMyStuff.StartTraderLeadSearch(query) then
				-- carry the dropdown choices over to the Guild Traders page
				for i, o in ipairs(FindMyStuff.TraderTypeOptions) do
					if o.lead and o.flag == typeOption.flag then self.traderChoice = { type = i, show = lc.show } end
				end
				self.traderText = text
				self:Open("traders")
			end
		end }
	local results, status = FindMyStuff.GetTabRows("leads", query)
	Append(rows, ResultRows(results, status and zo_strformat("<<1>>", status) or "Leads", "No leads found."))
	return { title = tab.name, rows = rows, count = #results, data2 = { "Showing", typeOption.name } }
end

---------------------------------------------------------------------------
-- Settings: renders the shared LAM option list as gamepad rows
---------------------------------------------------------------------------
local function Resolve(v)
	if type(v) == "function" then
		local ok, r = pcall(v)
		return ok and r or nil
	end
	return v
end

local function SliderStep(o, delta)
	local step = o.step or 1
	local v = (tonumber(o.getFunc()) or o.min or 0) + delta * step
	if v > (o.max or v) then v = o.min or v elseif v < (o.min or v) then v = o.max or v end
	o.setFunc(v)
end

function P.settings(self)
	local rows = {}
	local pendingHeader = "General"
	local options = FindMyStuff.Settings and FindMyStuff.Settings:BuildOptions() or {}
	for _, o in ipairs(options) do
		local tip = { o.name or o.title or "", o.tooltip or "" }
		local enabled = not Resolve(o.disabled)
		local row
		if o.type == "header" then
			pendingHeader = o.name
		elseif o.type == "description" then
			row = { text = Muted(o.text or ""), tip = { o.title or "", o.text or "" } }
		elseif o.type == "checkbox" and not o.isPCOnly then
			row = { text = string.format("%s: %s", o.name, OnOff(o.getFunc())), tip = tip, enabled = enabled,
				actionText = "Toggle", action = function() o.setFunc(not o.getFunc()) end }
		elseif o.type == "slider" then
			row = { text = string.format("%s: %s", o.name, "|cFFFFFF" .. tostring(o.getFunc()) .. "|r"), tip = tip, enabled = enabled,
				actionText = "Increase", action = function() SliderStep(o, 1) end,
				altText = "Decrease", alt = function() SliderStep(o, -1) end }
		elseif o.type == "button" and not o.opensUI and not o.isPCOnly then
			row = { text = o.name, tip = tip, enabled = enabled, actionText = "Select", action = function() o.func() end }
		end
		if row then
			row.header = pendingHeader
			pendingHeader = nil
			rows[#rows + 1] = row
		end
	end
	rows[#rows + 1] = { header = "Reset", text = "Reset all settings to defaults",
		tip = { "Reset", "Puts every Find My Stuff setting back to its default." },
		actionText = "Reset", action = function() if FindMyStuff.Settings then FindMyStuff.Settings:ResetToDefaults() end end }
	return { title = "Settings", rows = rows }
end

---------------------------------------------------------------------------
-- Ways in: main menu entry and L3 on the guild store
---------------------------------------------------------------------------
-- The gamepad main menu is built from the global ZO_MENU_ENTRIES table on
-- every refresh. Add one entry, built the same way the game builds its own.
local function InsertMainMenuEntry()
	if type(ZO_MENU_ENTRIES) ~= "table" or not ZO_GamepadEntryData then return false end
	for _, entry in ipairs(ZO_MENU_ENTRIES) do
		if entry.data and entry.data.fmsEntry then return true end
	end
	local data = {
		fmsEntry = true,
		name = "Find My Stuff",
		icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds",
		activatedCallback = function() FindMyStuff.ShowGamepad() end,
	}
	local entry = ZO_GamepadEntryData:New(data.name, data.icon)
	entry:SetIconTintOnSelection(true)
	if entry.SetIconDisabledTintOnSelection then entry:SetIconDisabledTintOnSelection(true) end
	entry.data = data
	entry.id = 9001
	entry:SetEnabled(true)
	table.insert(ZO_MENU_ENTRIES, entry)
	if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD.RefreshLists and MAIN_MENU_GAMEPAD.mainList then
		pcall(MAIN_MENU_GAMEPAD.RefreshLists, MAIN_MENU_GAMEPAD)
	end
	return true
end

-- Opening our scene would close the store, so L3 there only shows the
-- keyboard dialog; matches print to chat and fill the Guild Traders page.
-- (R3 is the store's own "Reset search" button, so we use L3.)
-- Left-aligned: the store shows the guild name in the bottom-right corner,
-- which covered a right-aligned button.
local storeDescriptor = {
	alignment = KEYBIND_STRIP_ALIGN_LEFT,
	{
		name = function()
			return FindMyStuff.IsTraderFilterActive() and "Find My Stuff (on)" or "Find My Stuff"
		end,
		keybind = "UI_SHORTCUT_LEFT_STICK",
		callback = function() GP:PromptTraderSearch() end,
	},
}

local function HookScene(scene)
	if not scene or scene.fmsHooked then return end
	scene.fmsHooked = true
	scene:RegisterCallback("StateChange", function(_, newState)
		if not KEYBIND_STRIP then return end
		if newState == SCENE_SHOWN then
			pcall(KEYBIND_STRIP.AddKeybindButtonGroup, KEYBIND_STRIP, storeDescriptor)
		elseif newState == SCENE_HIDING then
			pcall(KEYBIND_STRIP.RemoveKeybindButtonGroup, KEYBIND_STRIP, storeDescriptor)
		end
	end)
end

local function HookGuildStore()
	HookScene(SCENE_MANAGER:GetScene("gamepad_trading_house"))
end

---------------------------------------------------------------------------
-- Public entry points and setup
---------------------------------------------------------------------------
function FindMyStuff.ShowGamepad(page)
	if not GP:Show(page) then
		-- fall back to the keyboard window
		if FindMyStuff.ToggleWindow then FindMyStuff.ToggleWindow(page) end
	end
end

function FindMyStuff.IsGamepadShowing()
	return GP:IsShowing()
end

function FindMyStuff.CloseGamepad()
	GP:Close()
end

function FindMyStuff.InitGamepad()
	pcall(RegisterTextDialog)
	pcall(InsertMainMenuEntry)
	pcall(HookGuildStore)
	local function Refresh()
		if GP:IsShowing() then GP:Rebuild(true) end
	end
	CALLBACK_MANAGER:RegisterCallback(FindMyStuff.TRADER_CALLBACK, function()
		if GP.page == "traders" then Refresh() end
	end)
	CALLBACK_MANAGER:RegisterCallback("FindMyStuff_SettingsChanged", Refresh)
end
