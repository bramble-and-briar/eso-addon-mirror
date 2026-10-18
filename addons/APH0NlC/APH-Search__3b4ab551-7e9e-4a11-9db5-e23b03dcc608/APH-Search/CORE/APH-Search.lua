--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

APHSearchCore = APHSearchCore or {}
local SS = APHSearchCore
local AfterSceneSettled, AfterSceneShown, ApplyMapDestination, CanBrowseToSkillLine, ChampionClusterTarget
local CircleMapSpot, FindAchievementControl, FindAddonRowIndex, FindAntiquityTile, FindCollectibleTile
local FindConstellation, FindInventoryData, FindItemSetHeader, FindLeaderboardNode, FindOutfitStyleTile
local FindSettingControl, FindSkillRow, FinishMapSpot, Flash, FlashAndFollow, FlashSetting, FlashSkillLineNode
local FlashSkillRow, FollowFlash, GetKeybindScrollList, GetPanelMenuEntry, GoToAddonPanel, GoToMenuNode
local HookGameMenu, InventoryList, IsItemSetCategorySelected, IsSceneSettled, IsSceneShown, MapScene, MarkMapSpot
local OfferFastTravel, PreferSceneInGroup, RecallBlock, ResolveMapSpot, ScrollToAchievement, ScrollToSetting
local SelectChampionStar, SelectInventoryTab, SelectItemSetCategory, SelectPanelInMenu, SetFlashGuard
local SetMapToIndex, SetMapToZone, StarTint, StepToChampionStar, VisibleItemSetHeader, WatchAddonPanels
local WatchCollectibles, WatchFriends, WatchLeaderboards, WhenFound, WhenSettled

SS.name = "APH-Search"

local scope_names = {}

function SS.ScopeName(scope)
	local name = scope_names[scope]
	if name then return name end
	local id = _G["SI_APHS_SCOPE_" .. string.gsub(string.upper(scope), "[^A-Z0-9]+", "_")]
	name = id and GetString(id) or scope
	scope_names[scope] = name
	return name
end

function SS.L(key, ...)
	local id = _G["SI_APHS_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

SS.VERSION = "2026.10.15.14.36"
SS.KEYBIND_LAYER = "APH-Search"

local DEFAULTS = {
	match_tooltips = true,
	bar_opacity = 0.95,
	wayshrine_travel_prompt = true,
	chat_messages = true,
	hold_trigger_search = true,
	instant_results = not IsConsoleUI(),
	console_scopes = {},
	bar_x = -1,
	bar_y = -1,
	scopes_off = {},
	recent = {},
}

local MAX_RECENT = 10
local EMPTY = {}
local PANEL_SETTLE_MS = 100
local PANEL_RETRIES = 40
local FLASH_NAMESPACE = "APHSearch_Flash"
local HIGHLIGHT_MS = 4000
local BLINK_MS = 2000
local FLASH_GUARD_NAMESPACE = "APHSearch_FlashGuard"
local FLASH_FOLLOW_NAMESPACE = "APHSearch_FlashFollow"
local FOLLOW_CHECKS = 15
local GOLD = { 1, 0.82, 0.25, 1 }
local GREEN = { 0.18, 0.62, 0.25, 0.55 }

function SS.Print(text, always)
	if not always and SS.saved and SS.saved.chat_messages == false then return false end
	d("|c9CD04C[APH-Search]|r " .. text)
	return true
end

function SS.PanelName(panelId)
	local name = GetString("SI_SETTINGSYSTEMPANEL", panelId)
	if name ~= "" then return name end
	return SS.L("PANEL") .. tostring(panelId)
end

function SS.ResolveText(entry)
	local kind = type(entry)
	if kind == "string" then return entry end
	if kind == "number" then return GetString(entry) end
	if kind == "function" then
		local ok, result = pcall(entry)
		if ok and type(result) == "string" then return result end
		return nil
	end
	return nil
end

local last_query = ""

function SS.GetLastQuery() return last_query end
function SS.SetLastQuery(text) last_query = text or "" end

function SS.RememberSearch(text)
	if type(text) ~= "string" or text == "" then return false end
	local recent = SS.saved.recent
	for position = #recent, 1, -1 do
		if recent[position] == text then table.remove(recent, position) end
	end
	table.insert(recent, 1, text)
	while #recent > MAX_RECENT do table.remove(recent) end
	return true
end

function GetPanelMenuEntry(panelId)
	local options = KEYBOARD_OPTIONS
	if not options or not options.panelNames then return nil end

	local wanted = options.panelNames[panelId]
	if not wanted then return nil end

	local settings_category = GetString(SI_GAME_MENU_SETTINGS)
	for _, entry in ipairs(ZO_GameMenuManager_GetSubcategoriesEntries()) do
		if entry.name == wanted and entry.categoryName == settings_category then return entry end
	end
	return nil
end

function SS.IsPanelReachable(panelId)
	if IsInGamepadPreferredMode() then
		local data = GAMEPAD_SETTINGS_DATA
		if type(data) ~= "table" then return true end
		return data[panelId] ~= nil
	end

	local options = KEYBOARD_OPTIONS
	if not options or type(options.panelNames) ~= "table" then return true end
	return options.panelNames[panelId] ~= nil
end

function SelectPanelInMenu(panelId)
	local entry = GetPanelMenuEntry(panelId)
	if not entry then return false end

	local control = ZO_GameMenu_InGame
	local menu = control and control.gameMenu
	local tree = menu and menu.navigationTree
	if not tree then return false end

	local node = tree:GetTreeNodeByData(entry)
	if not node then return false end

	tree:SelectNode(node)
	return true
end

function FindSettingControl(panelId, system, settingId)
	local options = KEYBOARD_OPTIONS
	local panel = options and options.controlTable and options.controlTable[panelId]
	if not panel then return nil end

	for _, control in ipairs(panel) do
		local data = control.data
		if data and data.system == system and data.settingId == settingId then return control end
	end
	return nil
end

function ScrollToSetting(panelId, system, settingId)
	local control = FindSettingControl(panelId, system, settingId)
	if not control then return false end

	local window = ZO_OptionsWindow
	local scroll = window and window.GetNamedChild and window:GetNamedChild("Settings")
	if not scroll then return false end

	ZO_Scroll_ScrollControlIntoCentralView(scroll, control)
	FlashSetting(control)
	return true
end

local function HighlightBackdrop(control)
	if control.settings_search_glow then return control.settings_search_glow end

	local host = control.GetParent and control:GetParent() or control
	local glow = WINDOW_MANAGER:CreateControl(nil, host, CT_TEXTURE)
	glow:SetColor(unpack(GREEN))
	glow:SetDrawLayer(DL_BACKGROUND)
	glow:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
	glow:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
	glow:SetHidden(true)
	control.settings_search_glow = glow
	return glow
end

function SS.StopFlash()
	EVENT_MANAGER:UnregisterForUpdate(FLASH_NAMESPACE)
	local control, label = SS.flashing, SS.flashing_label
	SS.flashing, SS.flashing_label = nil, nil
	EVENT_MANAGER:UnregisterForUpdate(FLASH_GUARD_NAMESPACE)
	EVENT_MANAGER:UnregisterForUpdate(FLASH_FOLLOW_NAMESPACE)
	SS.flash_guard = nil
	if not control and not label then return false end

	if control and control.settings_search_glow then
		control.settings_search_glow:SetHidden(true)
	end
	if label and label.settings_search_color then
		label:SetColor(unpack(label.settings_search_color))
	end
	if label and label.settings_search_blend and label.SetBlendMode then
		label:SetBlendMode(label.settings_search_blend)
		label.settings_search_blend = nil
	end
	return true
end

function Flash(control, label)
	if not control and not label then return false end
	SS.StopFlash()

	if label and label.SetColor and not label.settings_search_color then
		label.settings_search_color = { label:GetColor() }
	end

	if control then
		local glow = HighlightBackdrop(control)
		glow:SetHidden(false)
	end
	SS.flashing, SS.flashing_label = control, label
	local on_color = label and label.settings_search_flash_color or GOLD
	if label and label.SetColor then label:SetColor(unpack(on_color)) end

	local total_ms = HIGHLIGHT_MS
	local half = BLINK_MS / 2

	local elapsed, gold = 0, true
	EVENT_MANAGER:RegisterForUpdate(FLASH_NAMESPACE, half, function()
		elapsed = elapsed + half
		gold = not gold
		if label and label.SetColor then
			if gold then
				label:SetColor(unpack(on_color))
			elseif label.settings_search_color then
				label:SetColor(unpack(label.settings_search_color))
			end
		end
		if elapsed >= total_ms then SS.StopFlash() end
	end)
	return true
end

function FollowFlash(find, label_of, checks)
	local left = checks or FOLLOW_CHECKS
	EVENT_MANAGER:RegisterForUpdate(FLASH_FOLLOW_NAMESPACE, PANEL_SETTLE_MS, function()
		left = left - 1
		if left <= 0 or not SS.flashing then
			EVENT_MANAGER:UnregisterForUpdate(FLASH_FOLLOW_NAMESPACE)
			return
		end
		local control = find()
		if control and control ~= SS.flashing then
			Flash(control, label_of(control))
			FollowFlash(find, label_of, left)
		end
	end)
end

function FlashAndFollow(find, label_of)
	local control = find()
	if not control then return false end
	Flash(control, label_of(control))
	FollowFlash(find, label_of)
	return true
end

function SetFlashGuard(check)
	SS.flash_guard = check
	EVENT_MANAGER:RegisterForUpdate(FLASH_GUARD_NAMESPACE, PANEL_SETTLE_MS, function()
		if not SS.flash_guard or SS.flash_guard() then return end
		SS.StopFlash()
	end)
end

function FlashSetting(control, label_name)
	if not control then return false end
	local label = control.GetNamedChild and control:GetNamedChild(label_name or "Name")
	return Flash(control, label)
end

local function FindNodeByName(node, name)
	if not node then return nil end

	local data = node.GetData and node:GetData()
	if data and data.name == name then return node end

	local children = node.GetChildren and node:GetChildren()
	for _, child in ipairs(children or {}) do
		local found = FindNodeByName(child, name)
		if found then return found end
	end
	return nil
end

function GoToMenuNode(node_name)
	local control = ZO_GameMenu_InGame
	local menu = control and control.gameMenu
	local tree = menu and menu.navigationTree
	if not tree then return false end

	local node = FindNodeByName(tree.rootNode, node_name)
	if node then
		tree:SelectNode(node)
		return true
	end

	local header = menu.headerControls and menu.headerControls[node_name]
	if header then
		tree:SelectNode(header)
		return true
	end
	return false
end

function GetKeybindScrollList()
	local manager = KEYBOARD_KEYBINDING_MANAGER
	local list = manager and manager.list
	return list and list.list or nil
end

local function VisibleKeybindRow(scroll, action)
	for _, control in pairs(scroll.activeControls or {}) do
		local entry = control.dataEntry and control.dataEntry.data
		if entry and entry.actionName == action then return control end
	end
	return nil
end

local function FlashVisibleKeybind(scroll, action)
	local control = VisibleKeybindRow(scroll, action)
	if not control then return false end

	Flash(control, control.actionLabel)
	return true
end

function SS.HighlightKeybind(action)
	local scroll = GetKeybindScrollList()
	if not scroll then return false end

	if FlashVisibleKeybind(scroll, action) then return true end

	local data = ZO_ScrollList_GetDataList(scroll)
	local position
	for index = 1, #data do
		local entry = data[index].data
		if entry and entry.actionName == action then
			position = index
			break
		end
	end
	if not position then return false end

	local function AfterScroll()
		SS.WaitUntil(function() return VisibleKeybindRow(scroll, action) ~= nil end,
			function() FlashVisibleKeybind(scroll, action) end, PANEL_RETRIES)
	end

	local NOT_INSTANT = false
	local scrolled = pcall(ZO_ScrollList_ScrollDataIntoView, scroll, position, AfterScroll, NOT_INSTANT)
	if not scrolled then return false end
	return true
end

function SS.GoToKeybinds(row)
	if not row then return false end
	SS.ShowMenuScene("gameMenuInGame")
	AfterSceneShown("gameMenuInGame", function()
		if not GoToMenuNode(GetString(SI_GAME_MENU_KEYBINDINGS)) then
			SS.Print(string.format(SS.L("COULD_NOT_OPEN_KEYBINDINGS_IS_UNDER"), row.label, row.detail))
			return
		end
		SS.WaitUntil(function() return GetKeybindScrollList() ~= nil end,
			function() SS.HighlightKeybind(row.action) end, PANEL_RETRIES)
	end)
	return true
end

function SS.GetAddonScrollList()
	local manager = ADD_ON_MANAGER
	return manager and manager.list or nil
end

local function VisibleAddonRow(scroll, folder)
	for _, control in pairs(scroll.activeControls or EMPTY) do
		local entry = control.dataEntry and control.dataEntry.data
		if entry and entry.addOnFileName == folder then return control end
	end
	return nil
end

function FindAddonRowIndex(folder)
	local scroll = SS.GetAddonScrollList()
	if not scroll or not folder then return nil end

	local data = ZO_ScrollList_GetDataList(scroll)
	for index = 1, #data do
		local entry = data[index].data
		if entry and entry.addOnFileName == folder then return index, scroll end
	end
	return nil
end

local function AddonLabel(control)
	return control.GetNamedChild and control:GetNamedChild("Name") or nil
end

function SS.HighlightAddon(folder)
	local position, scroll = FindAddonRowIndex(folder)
	if not position then return false end
	local function Find() return VisibleAddonRow(scroll, folder) end

	if Find() then
		WhenSettled(Find, function() FlashAndFollow(Find, AddonLabel) end)
		return true
	end

	local function AfterScroll()
		WhenSettled(Find, function() FlashAndFollow(Find, AddonLabel) end)
	end
	local NOT_INSTANT = false
	local scrolled = pcall(ZO_ScrollList_ScrollDataIntoView, scroll, position, AfterScroll, NOT_INSTANT)
	if not scrolled then return false end
	return true
end

local function AddonListSettled(folder)
	local last_count
	return function()
		local position, scroll = FindAddonRowIndex(folder)
		if not position then
			last_count = nil
			return nil
		end
		local count = #ZO_ScrollList_GetDataList(scroll)
		local settled = count == last_count
		last_count = count
		return settled and position or nil
	end
end

function SS.GoToAddons(row)
	if not row then return false end
	SS.ShowMenuScene("gameMenuInGame")
	AfterSceneShown("gameMenuInGame", function()
		if not GoToMenuNode(GetString(SI_GAME_MENU_ADDONS)) then return end
		WhenFound(AddonListSettled(row.folder), function() SS.HighlightAddon(row.folder) end)
	end)
	return true
end

function GoToAddonPanel(row)
	if not row or not row.panelControl then return false end
	local lam = LibAddonMenu2
	if not lam or type(lam.OpenToPanel) ~= "function" then return false end

	lam:OpenToPanel(row.panelControl)
	return true
end

function SS.GoToPanelControl(row)
	if not row or not row.panelControl or not row.control then return GoToAddonPanel(row) end
	if not GoToAddonPanel(row) then return false end

	zo_callLater(function()
		local scroll = row.panelControl.container
		if scroll then ZO_Scroll_ScrollControlIntoCentralView(scroll, row.control) end
		Flash(row.control, row.control.label)
	end, PANEL_SETTLE_MS)
	return true
end

function SS.GoToCommand(row)
	if not row or not row.command then return false end
	StartChatInput(row.command .. " ")
	return true
end

function SS.ShowMenuScene(scene)
	if not scene then return false end
	if SCENE_MANAGER:IsShowing(scene) then return true end

	local menu = MAIN_MENU_KEYBOARD
	if menu and type(menu.ShowScene) == "function" and menu.sceneInfo and menu.sceneInfo[scene] then
		menu:ShowScene(scene)
		return true
	end

	SCENE_MANAGER:Show(scene)
	return true
end

local SCENE_SETTLE_RETRIES = 10

function IsSceneShown(scene)
	local current = SCENE_MANAGER:GetCurrentScene()
	if not current then return SCENE_MANAGER:IsShowing(scene) end
	return current:GetName() == scene and current:GetState() == SCENE_SHOWN
end

function IsSceneSettled()
	local current = SCENE_MANAGER:GetCurrentScene()
	if not current then return true end
	return current:GetState() == SCENE_SHOWN
end

local function WaitFor(ready, fn, retries)
	if ready() then return fn() end

	local limit = retries or SCENE_SETTLE_RETRIES
	local function Wait(attempt)
		if ready() then return fn() end
		if attempt < limit then
			zo_callLater(function() Wait(attempt + 1) end, PANEL_SETTLE_MS)
		end
	end
	zo_callLater(function() Wait(1) end, PANEL_SETTLE_MS)
end

SS.WaitUntil = WaitFor
SS.FlashAndFollow = function(find, label_of) return FlashAndFollow(find, label_of) end
SS.WhenSettled = function(find, fn, retries, give_up) return WhenSettled(find, fn, retries, give_up) end

function WhenSettled(find, fn, retries, give_up)
	local limit = retries or PANEL_RETRIES
	local last_control, last_top
	local function Check(attempt)
		local control = find()
		if control and type(control.IsHidden) == "function" and not control:IsHidden() then
			local top = type(control.GetTop) == "function" and control:GetTop() or 0
			if control == last_control and top == last_top then return fn(control) end
			last_control, last_top = control, top
		else
			last_control, last_top = nil, nil
		end
		if attempt < limit then
			zo_callLater(function() Check(attempt + 1) end, PANEL_SETTLE_MS)
		elseif give_up then
			give_up()
		end
	end
	Check(1)
end

function WhenFound(find, fn, retries, give_up)
	local limit = retries or PANEL_RETRIES
	local function Check(attempt)
		local found, extra = find()
		if found then return fn(found, extra) end
		if attempt < limit then
			zo_callLater(function() Check(attempt + 1) end, PANEL_SETTLE_MS)
		elseif give_up then
			give_up()
		end
	end
	Check(1)
end

function AfterSceneShown(scene, fn)
	WaitFor(function() return IsSceneShown(scene) end, fn)
end

function AfterSceneSettled(fn)
	WaitFor(IsSceneSettled, fn)
end

function SS.GoToScene(row)
	if not row then return false end
	if row.action then return row.action() end
	if not row.scene then return false end
	if not SS.SceneExists(row.scene) then
		SS.Print(string.format(SS.L("IS_NOT_AVAILABLE_ON_THIS_CLIENT"), row.label))
		return false
	end

	return SS.ShowMenuScene(row.scene)
end

function FindAchievementControl(achievementId)
	local book = ACHIEVEMENTS
	local byId = book and book.achievementsById
	if not byId then return nil end

	local entry = byId[achievementId]
	if not entry and type(book.GetBaseAchievementId) == "function" then
		local ok, base = pcall(book.GetBaseAchievementId, book, achievementId)
		if ok and base then entry = byId[base] end
	end
	if not entry or type(entry.GetControl) ~= "function" then return nil end
	return entry:GetControl()
end

local function AchievementLabel(control)
	return control.GetNamedChild and control:GetNamedChild("Title") or nil
end

function SS.HighlightAchievement(achievementId)
	local function Find() return FindAchievementControl(achievementId) end
	return FlashAndFollow(Find, AchievementLabel)
end

function ScrollToAchievement(achievementId)
	local book = ACHIEVEMENTS
	local function Find() return FindAchievementControl(achievementId) end
	WhenSettled(Find, function(control)
		if book and book.contentList then ZO_Scroll_ScrollControlIntoCentralView(book.contentList, control) end
		WhenSettled(Find, function() SS.HighlightAchievement(achievementId) end)
	end)
end

function SS.GoToAchievement(row)
	if not row or not row.achievementId then return false end
	local book = ACHIEVEMENTS
	if not book or type(book.ShowAchievement) ~= "function" then
		SS.Print(string.format(SS.L("IS_UNDER_ACHIEVEMENTS"), row.label, row.where))
		return false
	end

	book:ShowAchievement(row.achievementId)
	AfterSceneShown("achievements", function() ScrollToAchievement(row.achievementId) end)
	return true
end

function FindSkillRow(skillData)
	local window = SKILLS_WINDOW
	local list = window and window.skillList
	local active = list and list.activeControls
	if not active then return nil end

	for _, control in pairs(active) do
		local progression = control.skillProgressionData
		if progression and type(progression.GetSkillData) == "function"
			and progression:GetSkillData() == skillData then
			return control
		end
	end
	return nil
end

local function SkillRowLabel(control)
	return control.nameLabel or (control.GetNamedChild and control:GetNamedChild("Name"))
end

function FlashSkillRow(skillData)
	local function Find() return FindSkillRow(skillData) end
	WhenSettled(Find, function() FlashAndFollow(Find, SkillRowLabel) end)
	return true
end

function CanBrowseToSkillLine(lineData)
	if not SS.IsSkillLineListed(lineData) then return false end

	local window = SKILLS_WINDOW
	local lookup = window and window.skillLineIdToNode
	if not lookup or type(lineData.GetId) ~= "function" then return true end
	return lookup[lineData:GetId()] ~= nil
end

function SS.BrowseToSkill(row)
	if not row or not row.skillData then return false end
	if type(row.skillData.GetSkillLineData) ~= "function" then return false end

	local window = SKILLS_WINDOW
	if not window or type(window.BrowseToSkill) ~= "function" then return false end

	SS.ShowMenuScene("skills")
	AfterSceneShown("skills", function()
		if not CanBrowseToSkillLine(row.skillData:GetSkillLineData()) then
			SS.Print(string.format(SS.L("IS_NOT_ON_A_SKILL_LINE"), row.label))
			return
		end
		window:BrowseToSkill(row.skillData)
		FlashSkillRow(row.skillData)
	end)
	return true
end

function SS.BrowseToSkillLine(row)
	if not row or not row.skillLineData then return false end

	local window = SKILLS_WINDOW
	if not window or type(window.BrowseToSkillLine) ~= "function" then return false end

	SS.ShowMenuScene("skills")
	AfterSceneShown("skills", function()
		if not CanBrowseToSkillLine(row.skillLineData) then
			SS.Print(string.format(SS.L("IS_NOT_A_SKILL_LINE_THIS"), row.label))
			return
		end
		window:BrowseToSkillLine(row.skillLineData)
		FlashSkillLineNode(row.skillLineData)
	end)
	return true
end

local function FindSkillLineControl(skillLineData)
	local window = SKILLS_WINDOW
	local lookup = window and window.skillLineIdToNode
	if not lookup or type(skillLineData.GetId) ~= "function" then return nil end

	local node = lookup[skillLineData:GetId()]
	if not node or type(node.GetControl) ~= "function" then return nil end
	return node:GetControl()
end

local function SkillLineLabel(control)
	return control.text or (control.GetNamedChild and control:GetNamedChild("Text"))
end

function FlashSkillLineNode(skillLineData)
	local function Find() return FindSkillLineControl(skillLineData) end
	WhenSettled(Find, function() FlashAndFollow(Find, SkillLineLabel) end)
	return true
end

function FindConstellation(disciplineData)
	local perks = CHAMPION_PERKS
	local list = perks and perks.constellations
	if not list or not disciplineData then return nil end

	if type(disciplineData.GetDisciplineIndex) == "function" then
		local found = list[disciplineData:GetDisciplineIndex()]
		if found then return found end
	end

	for _, constellation in pairs(list) do
		if type(constellation.GetChampionDisciplineData) == "function"
			and constellation:GetChampionDisciplineData() == disciplineData then
			return constellation
		end
	end
	return nil
end

local CHAMPION_RETRIES = 80

local function ChampionMachine(perks)
	local machine = perks and perks.stateMachine
	if machine and type(machine.IsCurrentState) == "function" then return machine end
	return nil
end

local function ChampionState(perks, name)
	local machine = ChampionMachine(perks)
	if not machine then return true end
	return machine:IsCurrentState(name)
end

local STAR_RESTORE = {}
SS.STAR_GLOW_BY_DISCIPLINE = {
	[CHAMPION_DISCIPLINE_TYPE_COMBAT] = { 0.3, 1, 0.3, 1 },
	[CHAMPION_DISCIPLINE_TYPE_WORLD] = { 1, 0.25, 0.25, 1 },
	[CHAMPION_DISCIPLINE_TYPE_CONDITIONING] = { 0.3, 0.55, 1, 1 },
}

local function StarDisciplineType(star)
	local skill = type(star.GetChampionSkillData) == "function" and star:GetChampionSkillData() or nil
	local discipline = skill and type(skill.GetChampionDisciplineData) == "function" and skill:GetChampionDisciplineData() or nil
	return discipline and type(discipline.GetType) == "function" and discipline:GetType() or nil
end

local function StarComposites(texture)
	local list = { texture }
	local alpha = type(texture.GetNamedChild) == "function" and texture:GetNamedChild("AlphaTextures") or nil
	if alpha then list[2] = alpha end
	return list
end

function StarTint(star)
	local texture = star and type(star.GetTexture) == "function" and star:GetTexture() or nil
	if not texture or type(texture.GetNumSurfaces) ~= "function" then return nil end

	local composites = StarComposites(texture)
	local originals = {}
	for _, composite in ipairs(composites) do
		for surface = 1, composite:GetNumSurfaces() do
			local r, g, b, a = composite:GetColor(surface)
			originals[#originals + 1] = { composite, surface, r, g, b, a }
		end
	end

	local tint = {
		settings_search_color = { STAR_RESTORE },
		settings_search_flash_color = SS.STAR_GLOW_BY_DISCIPLINE[StarDisciplineType(star)] or SS.STAR_GLOW_BY_DISCIPLINE[CHAMPION_DISCIPLINE_TYPE_COMBAT],
	}
	tint.SetColor = function(_, r, g, b, a)
		if r == STAR_RESTORE then
			for _, original in ipairs(originals) do
				local composite, surface = original[1], original[2]
				if surface <= composite:GetNumSurfaces() then
					composite:SetColor(surface, original[3], original[4], original[5], original[6])
				end
			end
			return
		end
		for _, composite in ipairs(composites) do
			for surface = 1, composite:GetNumSurfaces() do composite:SetColor(surface, r, g, b, a) end
		end
	end
	return tint
end

function SS.HighlightChampionStar(star)
	local perks = CHAMPION_PERKS
	SS.StopFlash()
	local glow = StarTint(star)
	local ring = perks and perks.selectedStarIndicatorTexture
	if glow then
		Flash(nil, glow)
	elseif ring then
		Flash(nil, ring)
		if ring.SetBlendMode and not ring.settings_search_blend then
			ring.settings_search_blend = TEX_BLEND_MODE_ADD
			ring:SetBlendMode(TEX_BLEND_MODE_ALPHA)
		end
	end
	if (glow or ring) and star and perks and type(perks.GetSelectedStar) == "function" then
		SetFlashGuard(function() return perks:GetSelectedStar() == star end)
	end

	if star and type(star.ShowKeyboardTooltip) == "function" and not IsInGamepadPreferredMode() then
		star:ShowKeyboardTooltip()
	end
	return glow ~= nil or ring ~= nil
end

local function CurrentClusterData(constellation)
	if type(constellation.GetCurrentCluster) ~= "function" then return nil end

	local cluster = constellation:GetCurrentCluster()
	if not cluster or type(cluster.GetChampionClusterData) ~= "function" then return nil end
	return cluster:GetChampionClusterData()
end

function SelectChampionStar(constellation, skillData)
	if type(constellation.GetCurrentCluster) ~= "function" then return false end

	local cluster = constellation:GetCurrentCluster()
	if not cluster or type(cluster.GetStarBySkillData) ~= "function" then return false end

	local star = cluster:GetStarBySkillData(skillData)
	if not star or type(constellation.SelectStar) ~= "function" then return false end

	constellation:SelectStar(star)
	if IsInGamepadPreferredMode() then
		SS.AimChampionCursor(star, function() SS.HighlightChampionStar(star) end)
	else
		SS.HighlightChampionStar(star)
	end
	return true
end

local CURSOR_AIM_TRIES = 12

function SS.AimChampionCursor(star, done)
	local perks = CHAMPION_PERKS
	local cursor = perks and perks:GetGamepadCursor()
	local texture = star:GetTexture()
	if not cursor or not cursor.cursorId or not texture then return done() end

	local tries = 0
	local function Aim()
		tries = tries + 1
		local x, y = texture:GetCenter()
		cursor.x, cursor.y = x, y
		cursor.control:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)
		cursor:UpdateCursorInfo()
		if cursor:GetLastSelectedStar() == star or tries >= CURSOR_AIM_TRIES then return done() end
		zo_callLater(Aim, 0)
	end
	Aim()
end

function ChampionClusterTarget(skill)
	if type(skill.GetChampionClusterData) ~= "function" then return nil end
	return skill:GetChampionClusterData()
end

function StepToChampionStar(perks, constellation, skill, target)
	if ChampionState(perks, "CLUSTER") then
		if perks:GetChosenConstellation() == constellation
			and CurrentClusterData(constellation) == target then
			return SelectChampionStar(constellation, skill)
		end
		if type(perks.ZoomOut) == "function" then perks:ZoomOut() end
		return false
	end

	if ChampionState(perks, "CONSTELLATION") then
		if perks:GetChosenConstellation() ~= constellation then
			if type(perks.ZoomOut) == "function" then perks:ZoomOut() end
			return false
		end
		if target then
			if type(perks.ChooseClusterData) ~= "function" then return false end
			perks:ChooseClusterData(target)
			return false
		end
		return SelectChampionStar(constellation, skill)
	end

	if ChampionState(perks, "RING") then
		if type(perks.ChooseConstellationNode) == "function"
			and type(constellation.GetFirstRingNode) == "function" then
			perks:ChooseConstellationNode(constellation:GetFirstRingNode())
		end
	end
	return false
end

function SS.ShowChampionSkill(row)
	if not row or not row.championSkillData then return false end

	local skill = row.championSkillData
	local scene = IsInGamepadPreferredMode() and "gamepad_championPerks_root" or "championPerks"
	if IsInGamepadPreferredMode() then SCENE_MANAGER:Show(scene) else SS.ShowMenuScene(scene) end
	AfterSceneShown(scene, function()
		local perks = CHAMPION_PERKS
		if not perks then return end

		local target = nil
		if not row.championPortal then target = ChampionClusterTarget(skill) end
		local attempt = 0
		local function Step()
			attempt = attempt + 1
			local constellation = FindConstellation(row.disciplineData)
			if constellation and StepToChampionStar(perks, constellation, skill, target) then
				return
			end
			if attempt < CHAMPION_RETRIES then
				zo_callLater(Step, PANEL_SETTLE_MS)
			end
		end
		zo_callLater(Step, PANEL_SETTLE_MS)
	end)
	return true
end

function SS.SetTitle(row)
	if not row then return false end

	SelectTitle(row.titleIndex)
	if row.titleIndex then
		SS.Print(string.format(SS.L("TITLE_SET_TO"), row.label))
	else
		SS.Print(SS.L("TITLE_CLEARED"))
	end
	return true
end

function SS.PlayEmote(row)
	if not row or not row.emoteIndex then return false end

	if SS.IsShowingBaseScene() then
		PlayEmoteByIndex(row.emoteIndex)
		return true
	end
	SCENE_MANAGER:ShowBaseScene()
	WaitFor(function() return SS.IsShowingBaseScene() and IsSceneShown(SCENE_MANAGER:GetCurrentScene():GetName()) end, function()
		PlayEmoteByIndex(row.emoteIndex)
	end)
	return true
end

function SS.FocusedQuestIndex()
	for index = 1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(index) then
			if GetTrackedIsAssisted(TRACK_TYPE_QUEST, index) then return index end
		end
	end
	return nil
end

function SS.ShowQuestOnMap(row)
	if not row then return false end

	local index = row.questIndex
	if row.focusedQuest then
		index = SS.FocusedQuestIndex()
		if not index then
			SS.Print(SS.L("NO_QUEST_IS_FOCUSED_RIGHT_NOW"))
			return false
		end
	end
	if not index then return false end

	ZO_WorldMap_ShowQuestOnMap(index)
	local label = GetJournalQuestName(index)
	AfterSceneShown(MapScene(), function()
		WhenFound(function() return ZO_WorldMap_GetPinManager():GetQuestConditionPin(index) end, function(pin)
			local x, z = pin:GetNormalizedPosition()
			PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, z)
			SS.SuggestTravelForQuest(index, label)
		end)
	end)
	return true
end

function FindAntiquityTile(antiquityId)
	local journal = ANTIQUITY_JOURNAL_KEYBOARD
	local pool = journal and journal.antiquityTileControlPool
	if not pool or type(pool.GetActiveObjects) ~= "function" then return nil end

	for _, control in pairs(pool:GetActiveObjects()) do
		local tile = control.owner
		local data = tile and tile.tileData
		if data and type(data.GetId) == "function" and data:GetId() == antiquityId then
			return control, tile.title
		end
	end
	return nil
end

local function AntiquityLabel(control)
	return control.owner and control.owner.title or nil
end

function SS.HighlightAntiquity(antiquityId)
	local function Find() return (FindAntiquityTile(antiquityId)) end
	return FlashAndFollow(Find, AntiquityLabel)
end

function SS.ShowAntiquity(row)
	if not row or not row.antiquityId then return false end

	local journal = ANTIQUITY_JOURNAL_KEYBOARD
	if not journal or type(journal.ShowCategory) ~= "function" then
		SS.Print(string.format(SS.L("IS_IN_THE_ANTIQUITIES_CODEX"), row.label))
		return false
	end

	local category = GetAntiquityCategoryId(row.antiquityId)
	if not category or category == 0 then
		SS.Print(string.format(SS.L("HAS_NO_CODEX_CATEGORY"), row.label))
		return false
	end

	local function OpenCategory()
		journal:ShowCategory(category)
		local function Find() return (FindAntiquityTile(row.antiquityId)) end
		WhenSettled(Find, function() SS.HighlightAntiquity(row.antiquityId) end)
	end

	if not SS.SceneExists("antiquityJournalKeyboard") then
		OpenCategory()
		return true
	end

	SS.ShowMenuScene("antiquityJournalKeyboard")
	AfterSceneShown("antiquityJournalKeyboard", OpenCategory)
	return true
end

local TIMED_ACTIVITIES_SCENE = "TimedActivitiesKeyboard"
local TOMES_SCENE = "TamrielTomesSceneKeyboard"
local TOMES_SCENE_GROUP = "tamrielTomesSceneGroup"

function SS.EnsureDeferredInit(screen)
	if not screen then return false end
	if type(screen.PerformDeferredInitialize) ~= "function" then return false end
	screen:PerformDeferredInitialize()
	return true
end

function PreferSceneInGroup(groupName, scene)
	local group = SCENE_MANAGER:GetSceneGroup(groupName)
	if not group then return false end
	if type(group.HasScene) == "function" and not group:HasScene(scene) then return false end

	group:SetActiveScene(scene)
	return true
end

function SS.ShowTimedActivities(activityType)
	local screen = TIMED_ACTIVITIES_KEYBOARD
	if not screen or type(screen.SelectActivityTypeCategory) ~= "function" then return false end

	local function SelectTab()
		SS.EnsureDeferredInit(screen)
		screen:SelectActivityTypeCategory(activityType)
	end

	if IsSceneShown(TIMED_ACTIVITIES_SCENE) then
		SelectTab()
		return true
	end

	local function OpenChallenges()
		local manager = TIMED_ACTIVITIES_MANAGER
		if manager and type(manager.ShowTimedActivitiesScene) == "function" then
			manager:ShowTimedActivitiesScene()
		else
			SS.ShowMenuScene(TIMED_ACTIVITIES_SCENE)
		end
		AfterSceneShown(TIMED_ACTIVITIES_SCENE, SelectTab)
	end

	if IsSceneShown(TOMES_SCENE) then
		OpenChallenges()
		return true
	end

	PreferSceneInGroup(TOMES_SCENE_GROUP, TIMED_ACTIVITIES_SCENE)
	SS.ShowMenuScene(TIMED_ACTIVITIES_SCENE)
	AfterSceneShown(TIMED_ACTIVITIES_SCENE, SelectTab)
	return true
end

local function SelectGuildSelectorEntry(title)
	local selector = GUILD_SELECTOR
	if not selector or type(selector.SelectGuild) ~= "function" then return false end

	local box = selector.comboBox
	if not box or type(box.GetItems) ~= "function" then return false end

	for _, entry in ipairs(box:GetItems()) do
		if entry.selectedText == title then
			selector:SelectGuild(entry)
			return true
		end
	end
	return false
end

function SS.ShowGuildSelectorScene(scene, title)
	if not SS.SceneExists(scene) then return false end

	SS.ShowMenuScene(scene)
	AfterSceneSettled(function() SelectGuildSelectorEntry(title) end)
	return true
end

function MapScene()
	return IsInGamepadPreferredMode() and "gamepad_worldMap" or "worldMap"
end
local WAYPOINT_SLACK = 0.001

function SetMapToIndex(map_index)
	if not map_index or map_index == 0 then return false end

	WORLD_MAP_MANAGER:SetMapByIndex(map_index)
	return true
end

function SetMapToZone(zoneId)
	if not zoneId or zoneId == 0 then return false end

	return SetMapToIndex(GetMapIndexByZoneId(zoneId))
end

function ResolveMapSpot(row)
	if row.nodeIndex then
		local _, _, x, z, _, _, _, shown = GetFastTravelNodeInfo(row.nodeIndex)
		if shown then return x, z end
		return nil
	end

	if row.zoneIndex and row.poiIndex then
		local x, z, _, _, shown = GetPOIMapInfo(row.zoneIndex, row.poiIndex)
		if shown then return x, z end
	end
	return nil
end

local PING_TAG = "APHSearchPing"

function CircleMapSpot(x, z)
	local manager = ZO_WorldMap_GetPinManager()
	if not manager then return false end

	manager:RemovePins("pings", MAP_PIN_TYPE_QUEST_PING)
	manager:CreatePin(MAP_PIN_TYPE_QUEST_PING, PING_TAG, x, z)
	return true
end

function MarkMapSpot(x, z)
	if type(x) ~= "number" or type(z) ~= "number" then return false end

	PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, z)
	local function Landed()
		local wx, wz = GetMapPlayerWaypoint()
		return wx and wz and math.abs(wx - x) < WAYPOINT_SLACK and math.abs(wz - z) < WAYPOINT_SLACK
	end
	local function Pan()
		ZO_WorldMap_PanToNormalizedPosition(x, z)
		CircleMapSpot(x, z)
	end
	WhenFound(Landed, Pan, nil, Pan)
	return true
end

function SS.TravelNodeBlock(nodeIndex)
	if not nodeIndex then return SS.L("THAT_PLACE_HAS_NO_TRAVEL_POINT") end

	local known, _, _, _, _, _, _, _, locked = GetFastTravelNodeInfo(nodeIndex)
	if not known then return SS.L("YOU_HAVE_NOT_DISCOVERED_IT_YET") end
	if locked then return SS.L("IT_IS_LOCKED_BEHIND_A_COLLECTIBLE") end
	if GetFastTravelNodeOutboundOnlyInfo(nodeIndex) then
		return SS.L("YOU_CAN_TRAVEL_FROM_THERE_BUT")
	end
	return nil
end

function RecallBlock()
	if IsUnitDead("player") then return SS.L("YOU_ARE_DEAD") end
	if IsInCampaign() then return SS.L("RECALL_DOES_NOT_WORK_INSIDE_A") end
	if not CanLeaveCurrentLocationViaTeleport() then
		return SS.L("YOU_CANNOT_TELEPORT_OUT_OF_WHERE")
	end

	local _, premium_left = GetRecallCooldown()
	if premium_left and premium_left > 0 then return SS.L("RECALL_IS_STILL_ON_COOLDOWN") end
	return nil
end

function OfferFastTravel(nodeIndex, outside)
	if not nodeIndex then return false end

	local _, name = GetFastTravelNodeInfo(nodeIndex)
	if not name or name == "" then return false end

	if SS.TravelNodeBlock(nodeIndex) then return false end

	local houseId = GetFastTravelNodeHouseId(nodeIndex)

	ZO_Dialogs_ReleaseDialog("FAST_TRAVEL_CONFIRM")
	ZO_Dialogs_ReleaseDialog("RECALL_CONFIRM")
	ZO_Dialogs_ReleaseDialog("TRAVEL_TO_HOUSE_CONFIRM")

	if houseId ~= 0 then
		ZO_Dialogs_ShowPlatformDialog("TRAVEL_TO_HOUSE_CONFIRM",
			{ houseId = houseId, travelOutside = outside == true }, { mainTextParams = { name } })
		return true
	end

	if ZO_Map_GetFastTravelNode() ~= nil then
		ZO_Dialogs_ShowPlatformDialog("FAST_TRAVEL_CONFIRM", { nodeIndex = nodeIndex },
			{ mainTextParams = { name } })
		return true
	end

	local stopped = RecallBlock()
	if stopped then
		SS.Print(string.format(SS.L("CANNOT_RECALL_TO"), name, stopped))
		return false
	end

	ZO_Dialogs_ShowPlatformDialog("RECALL_CONFIRM", { nodeIndex = nodeIndex },
		{ mainTextParams = { name } })
	return true
end

function SS.JumpTo(way)
	if way.who == "group" then
		JumpToGroupMember(way.name)
	elseif way.who == "guild" then
		JumpToGuildMember(way.name)
	else
		JumpToFriend(way.name)
	end
end

local function WhoText(way)
	if way.who == "group" then return SS.L("JUMP_GROUP_MEMBER", way.name) end
	if way.who == "guild" then return SS.L("JUMP_GUILD_MEMBER", way.name, way.guild or "") end
	return SS.L("JUMP_FRIEND", way.name)
end

function SS.OfferWay(way, destZone)
	if not SS.saved.wayshrine_travel_prompt then return true end
	if way.kind ~= "player" then return OfferFastTravel(way.node, way.outside) end
	local zone = zo_strformat("<<1>>", GetZoneNameById(destZone))
	LibAPH.ShowDialogHidingWindows({}, "APHSEARCH_JUMP", SS.L("JUMP_TITLE"), SS.L("JUMP_BODY", WhoText(way), zone), {
		{ text = SI_DIALOG_ACCEPT, callback = function() SS.JumpTo(way) end },
		{ text = SI_DIALOG_DECLINE },
	})
	return true
end

function SS.NoWayInto(destZone)
	SS.Print(SS.L("NO_WAY_INTO", zo_strformat("<<1>>", GetZoneNameById(destZone))))
end

function SS.SuggestTravel(destZone, x, z, quiet)
	if destZone and destZone ~= 0 and SS.Travel.SameZone(destZone, (GetUnitRawWorldPosition("player"))) then return true end
	local way = SS.Travel.WayInto(destZone, x, z)
	if not way then
		if not quiet then SS.NoWayInto(destZone) end
		return false
	end
	SS.OfferWay(way, destZone)
	return true
end

local function ShownMapZone()
	local index = GetCurrentMapZoneIndex()
	return index and GetZoneId(index) or 0
end

local ZOOM_OUT_TRIES = 2

function SS.SuggestTravelForQuest(index, label, tries)
	local manager = ZO_WorldMap_GetPinManager()
	local pin = manager:GetQuestConditionPin(index)
	if not pin then return false end
	local x, z = pin:GetNormalizedPosition()
	local quiet = (tries or 0) < ZOOM_OUT_TRIES
	if SS.SuggestTravel(ShownMapZone(), x, z, quiet) then return true end
	if quiet and MapZoomOut() == SET_MAP_RESULT_MAP_CHANGED then
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
		WhenFound(function()
			local next_pin = manager:GetQuestConditionPin(index)
			return next_pin ~= pin and next_pin or nil
		end, function() SS.SuggestTravelForQuest(index, label, (tries or 0) + 1) end, nil, function()
			SS.NoWayInto(ShownMapZone())
		end)
		return false
	end
	if quiet then SS.NoWayInto(ShownMapZone()) end
	return false
end

function ApplyMapDestination(row)
	if row.mapIndex and not row.nodeIndex then return SetMapToIndex(row.mapIndex) end
	return SetMapToZone(row.zoneId)
end

function FinishMapSpot(row)
	if row.mapIndex and not row.nodeIndex then return true end

	local x, z = ResolveMapSpot(row)
	if x then MarkMapSpot(x, z) end
	local destZone = row.zoneId or ShownMapZone()
	if row.nodeIndex and not SS.TravelNodeBlock(row.nodeIndex) then
		if SS.saved.wayshrine_travel_prompt then OfferFastTravel(row.nodeIndex) end
		return true
	end
	SS.SuggestTravel(destZone, x, z)
	return x ~= nil or row.nodeIndex ~= nil
end

function SS.GoToMapSpot(row)
	if not row then return false end

	local scene = MapScene()
	SS.ShowMenuScene(scene)
	AfterSceneShown(scene, function()
		ApplyMapDestination(row)
		FinishMapSpot(row)
	end)
	return true
end

function SelectInventoryTab(mode)
	local bar = INVENTORY_MENU_BAR
	local mode_bar = bar and bar.modeBar
	if not mode or not mode_bar or type(mode_bar.SelectFragment) ~= "function" then return false end

	mode_bar:SelectFragment(mode)
	return true
end

function SS.ShowInventoryTab(mode)
	if not mode then return false end

	local bar = INVENTORY_MENU_BAR
	local mode_bar = bar and bar.modeBar
	if not mode_bar or type(mode_bar.SelectFragment) ~= "function" then return false end

	SS.ShowMenuScene("inventory")
	AfterSceneShown("inventory", function() SelectInventoryTab(mode) end)
	return true
end

local INVENTORY_FOR_BAG = {
	[BAG_BACKPACK] = INVENTORY_BACKPACK,
	[BAG_VIRTUAL] = INVENTORY_CRAFT_BAG,
}

local INVENTORY_MODE_FOR_BAG = {
	[BAG_BACKPACK] = SI_INVENTORY_MODE_ITEMS,
	[BAG_VIRTUAL] = SI_INVENTORY_MODE_CRAFT_BAG,
}

function InventoryList(bagId)
	local which = INVENTORY_FOR_BAG[bagId]
	local manager = PLAYER_INVENTORY
	if not which or not manager or type(manager.inventories) ~= "table" then return nil end

	local inventory = manager.inventories[which]
	return inventory and inventory.listView or nil
end

function FindInventoryData(list, bagId, slotIndex)
	if not list then return nil end

	for index, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
		local data = entry.data
		if data and data.bagId == bagId and data.slotIndex == slotIndex then
			return index, data
		end
	end
	return nil
end

local function InventoryRowLabel(control)
	return control.GetNamedChild and control:GetNamedChild("Name") or nil
end

function SS.FlashInventoryRow(row)
	local list = InventoryList(row.bagId)
	local index, data = FindInventoryData(list, row.bagId, row.slotIndex)
	if not index then return false end

	local NO_CALLBACK, INSTANTLY = nil, true
	ZO_ScrollList_ScrollDataIntoView(list, index, NO_CALLBACK, INSTANTLY)

	local function Find() return data.slotControl end
	WhenSettled(Find, function() FlashAndFollow(Find, InventoryRowLabel) end)
	return true
end

function SS.ShowInventoryItem(row)
	if not row or not row.bagId or not row.slotIndex then return false end

	local mode = INVENTORY_MODE_FOR_BAG[row.bagId]
	local bar = INVENTORY_MENU_BAR
	if not mode or not bar or not bar.modeBar then return false end

	SS.ShowMenuScene("inventory")
	AfterSceneShown("inventory", function()
		SelectInventoryTab(mode)
		SS.WaitUntil(function()
			return FindInventoryData(InventoryList(row.bagId), row.bagId, row.slotIndex) ~= nil
		end, function() SS.FlashInventoryRow(row) end)
	end)
	return true
end

function SS.IsShowingBaseScene()
	return SCENE_MANAGER:IsShowingBaseScene()
end

function FindCollectibleTile(collectibleId)
	local book = SYSTEMS:GetObject(ZO_COLLECTIONS_SYSTEM_NAME)
	if not book or type(book.GetEntryByCollectibleId) ~= "function" then return nil end

	local grid = book.gridListPanelList
	if not grid then return nil end

	local entry = book:GetEntryByCollectibleId(collectibleId)
	if not entry then return nil end

	local control = grid:GetControlFromData(entry)
	if not control then return nil end

	return control, control.GetNamedChild and control:GetNamedChild("Title") or nil
end

local function CollectibleLabel(control)
	return control.GetNamedChild and control:GetNamedChild("Title") or nil
end

function SS.HighlightCollectible(collectibleId)
	local function Find() return (FindCollectibleTile(collectibleId)) end
	return FlashAndFollow(Find, CollectibleLabel)
end

local OWN_BOOK = { "IsDLCCategory", "IsHousingCategory", "IsOutfitStylesCategory", "IsTributePatronCategory" }

function SS.SearchCollectionsFor(collectibleId)
	local book = SYSTEMS:GetObject(ZO_COLLECTIONS_SYSTEM_NAME)
	local box = book and book.contentSearchEditBox
	local data = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(collectibleId)
	if not box or not data then return false end
	local category = data:GetCategoryData()
	for _, method in ipairs(OWN_BOOK) do
		if category and type(category[method]) == "function" and category[method](category) then return false end
	end
	box:SetText(data:GetFormattedName())
	local function Find() return (FindCollectibleTile(collectibleId)) end
	WhenSettled(Find, function() SS.HighlightCollectible(collectibleId) end)
	return true
end

function SS.BrowseToCollectible(row)
	if not row or not row.collectibleId then return false end

	local book = COLLECTIONS_BOOK_SINGLETON
	if not book or type(book.BrowseToCollectible) ~= "function" then return false end

	local function Browse()
		book:BrowseToCollectible(row.collectibleId)
		local function Find() return (FindCollectibleTile(row.collectibleId)) end
		WhenSettled(Find, function() SS.HighlightCollectible(row.collectibleId) end, nil,
			function() SS.SearchCollectionsFor(row.collectibleId) end)
	end

	if SS.IsShowingBaseScene() then
		Browse()
		return true
	end

	SCENE_MANAGER:ShowBaseScene()
	SS.WaitUntil(SS.IsShowingBaseScene, Browse)
	return true
end

function SS.UseCollectibleRow(row)
	local manager = ZO_COLLECTIBLE_DATA_MANAGER
	local data = row and row.collectibleId and manager and manager:GetCollectibleDataById(row.collectibleId)
	if not data then return false end

	local actor = GAMEPLAY_ACTOR_CATEGORY_PLAYER
	if data:IsBlocked(actor) then
		local reason = type(data.GetBlockReason) == "function" and data:GetBlockReason(actor) or ""
		SS.Print(reason ~= "" and reason or string.format(SS.L("CAN_T_BE_USED_RIGHT_NOW"), row.label))
		return false
	end
	if not data:IsUsable(actor) then
		SS.Print(string.format(SS.L("CAN_T_BE_USED_RIGHT_NOW"), row.label))
		return false
	end
	data:Use(actor)
	return true
end

local function TileIcon(control)
	return control.GetNamedChild and control:GetNamedChild("Icon") or nil
end

function FindOutfitStyleTile(collectibleData)
	local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
	if not panel or type(panel.GetEntryByCollectibleData) ~= "function" then return nil end
	local entry = panel:GetEntryByCollectibleData(collectibleData)
	local grid = panel.gridListPanelList
	if not entry or not grid then return nil end
	return grid:GetControlFromData(entry)
end

local function RevealOutfitStyle(collectibleData)
	local panel = ZO_OUTFIT_STYLES_PANEL_KEYBOARD
	if not collectibleData:IsUnlocked() and ZO_OUTFIT_MANAGER and not ZO_OUTFIT_MANAGER:GetShowLocked() then
		ZO_OUTFIT_MANAGER:SetShowLocked(true)
	end
	local dropdown = panel and panel.typeFilterDropDown
	if dropdown and panel.allTypesFilterEntry and dropdown:GetSelectedItemData() ~= panel.allTypesFilterEntry then
		dropdown:SelectItem(panel.allTypesFilterEntry)
	end
	local book = ZO_OUTFIT_STYLES_BOOK_KEYBOARD
	local box = book and book.contentSearchEditBox
	if box and box:GetText() ~= "" then box:SetText("") end
end

function SS.GoToOutfitStyle(row)
	local manager = ZO_COLLECTIBLE_DATA_MANAGER
	local data = row and row.collectibleId and manager and manager:GetCollectibleDataById(row.collectibleId)
	local book = ZO_OUTFIT_STYLES_BOOK_KEYBOARD
	if not data then return false end
	if IsInGamepadPreferredMode() or not book then return SS.BrowseToCollectible(row) end

	PreferSceneInGroup("collectionsSceneGroup", "outfitStylesBook")
	SS.ShowMenuScene("outfitStylesBook")
	AfterSceneShown("outfitStylesBook", function()
		RevealOutfitStyle(data)
		WhenFound(function() return book.fragment and book.fragment:IsShowing() end, function()
			book:NavigateToCollectibleData(data)
			local function Find() return FindOutfitStyleTile(data) end
			WhenSettled(Find, function() FlashAndFollow(Find, TileIcon) end, nil, function()
				SS.Print(string.format(SS.L("COULD_NOT_FIND_IN_OUTFIT_STYLES"), row.label))
			end)
		end)
	end)
	return true
end

function FindItemSetHeader(setId)
	local book = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD
	local grid = book and book.gridListPanelList
	local list = grid and grid.list
	if not list then return nil end

	for index, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
		local header = entry.data and entry.data.header
		if header and type(header.GetId) == "function" and header:GetId() == setId then return index, list end
	end
	return nil
end

function VisibleItemSetHeader(setId)
	local _, list = FindItemSetHeader(setId)
	for _, control in pairs(list and list.activeControls or EMPTY) do
		local header = control.dataEntry and control.dataEntry.data and control.dataEntry.data.header
		if header and type(header.GetId) == "function" and header:GetId() == setId then return control end
	end
	return nil
end

local function SetHeaderLabel(control)
	return control.nameLabel or (control.GetNamedChild and control:GetNamedChild("Name")) or nil
end

local function RevealItemSet(setData, widen)
	local book = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD
	local manager = ITEM_SET_COLLECTIONS_DATA_MANAGER
	local box = book and book.searchEditBox
	if box and box:GetText() ~= "" then box:SetText("") end
	if not setData:HasAnyUnlockedPieces() and not manager:GetShowLocked() then manager:SetShowLocked(true) end
	if widen then manager:SetEquipmentFilterTypes({}) end
end

function SelectItemSetCategory(categoryData)
	local tree = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD and ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.categoryTree
	local node = tree and categoryData and tree:GetTreeNodeByData(categoryData)
	if not node then return false end
	if node:IsLeaf() then
		tree:SelectNode(node)
	else
		local OPEN, USER_REQUESTED = true, true
		tree:SetNodeOpen(node, OPEN, USER_REQUESTED)
	end
	return true
end

function IsItemSetCategorySelected(categoryData)
	local tree = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD and ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.categoryTree
	local selected = tree and tree:GetSelectedData()
	return selected ~= nil and categoryData ~= nil and selected:GetId() == categoryData:GetId()
end

function SS.GoToItemSet(row)
	local manager = ITEM_SET_COLLECTIONS_DATA_MANAGER
	local book = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD
	local setData = row and row.itemSetId and manager and manager:GetItemSetCollectionData(row.itemSetId)
	if not setData then return false end
	if IsInGamepadPreferredMode() or not book then
		SS.Print(string.format(SS.L("IS_UNDER_COLLECTIONS"), row.label, row.where))
		return false
	end

	local function Reveal()
		local function Find() return VisibleItemSetHeader(row.itemSetId) end
		WhenSettled(Find, function() FlashAndFollow(Find, SetHeaderLabel) end)
	end

	local function Scroll(index, list)
		local NOT_INSTANT = false
		if not pcall(ZO_ScrollList_ScrollDataIntoView, list, index, Reveal, NOT_INSTANT) then Reveal() end
	end

	PreferSceneInGroup("collectionsSceneGroup", "itemSetsBook")
	SS.ShowMenuScene("itemSetsBook")
	AfterSceneShown("itemSetsBook", function()
		local category = setData:GetCategoryData()
		local function Find()
			if not IsItemSetCategorySelected(category) then
				SelectItemSetCategory(category)
				return nil
			end
			return FindItemSetHeader(row.itemSetId)
		end
		RevealItemSet(setData, false)
		WhenFound(Find, Scroll, nil, function()
			RevealItemSet(setData, true)
			WhenFound(Find, Scroll, nil, function()
				SS.Print(string.format(SS.L("COULD_NOT_FIND_UNDER"), row.label, row.where))
			end)
		end)
	end)
	return true
end

function FindLeaderboardNode(node, name)
	if type(node.GetChildren) ~= "function" then return nil end

	for _, child in ipairs(node:GetChildren() or EMPTY) do
		local data = type(child.GetData) == "function" and child:GetData() or nil
		if data and data.name == name then return child end

		local found = FindLeaderboardNode(child, name)
		if found then return found end
	end
	return nil
end

function SS.GoToLeaderboard(row)
	if not row or not row.leaderboardName then return false end

	SS.ShowMenuScene("leaderboards")
	AfterSceneShown("leaderboards", function()
		local tree = LEADERBOARDS and LEADERBOARDS.navigationTree
		if not tree or not tree.rootNode or type(tree.SelectNode) ~= "function" then return end

		SS.WaitUntil(function()
			return FindLeaderboardNode(tree.rootNode, row.leaderboardName) ~= nil
		end, function()
			tree:SelectNode(FindLeaderboardNode(tree.rootNode, row.leaderboardName))
		end)
	end)
	return true
end

function SS.GoToFriend(row)
	if not row or not row.friendName then return false end

	if row.friendAction == "whisper" then
		WaitFor(function() return not ZO_Dialogs_IsShowingDialog() end, function()
			if not IsConsoleUI() then
				StartChatInput("", CHAT_CHANNEL_WHISPER, row.friendName)
				return
			end
			if IsCommunicationRestricted() and not CanCommunicateWith(row.friendName) then return end
			local chat = ZO_GetChatSystem()
			local ok = pcall(function()
				chat:SetHUDEnabled(true)
				chat:StartTextEntry("", CHAT_CHANNEL_WHISPER, row.friendName, true)
			end)
			if not ok then SS.ShowMenuScene("friendsList") end
		end)
		return true
	end

	if row.friendAction == "invite" then
		local NOT_FROM_CHAT, SHOW_INVITED_MESSAGE = false, true
		TryGroupInviteByName(row.friendName, NOT_FROM_CHAT, SHOW_INVITED_MESSAGE)
		return true
	end

	if row.friendAction == "jump" then
		JumpToFriend(row.friendName)
		return true
	end

	return SS.ShowMenuScene("friendsList")
end

function SS.SearchCrownStore(row)
	ShowMarketAndSearch(row and row.query or "", MARKET_OPEN_OPERATION_DIRECT)
	return true
end

function SS.GoToSupportScreen(row)
	if not row or not row.supportFragment then return false end

	local screen = HELP_CUSTOMER_SUPPORT_KEYBOARD
	if not screen or type(screen.OpenScreen) ~= "function" then
		SS.Print(string.format(SS.L("IS_UNDER_CUSTOMER_SUPPORT"), row.label))
		return false
	end

	screen:OpenScreen(row.supportFragment)
	return true
end

function SS.GoToHelp(row)
	if not row or not row.helpCategory then return false end
	local help = HELP
	if not help or type(help.ShowSpecificHelp) ~= "function" then
		SS.Print(string.format(SS.L("IS_UNDER_HELP"), row.label, row.where))
		return false
	end

	help:ShowSpecificHelp(row.helpCategory, row.helpIndex)
	return true
end

function SS.GoTo(row)
	if not row then return false end
	if type(row.go) == "function" then return row.go(row) end
	return false
end

function SS.GoToSetting(entry)
	if not entry then return false end

	local where = entry.where or SS.PanelName(entry.panel)

	if IsInGamepadPreferredMode() then
		SCENE_MANAGER:Show("gamepad_options_root")
		SS.Print(string.format(SS.L("LIVES_UNDER"), entry.label, where))
		return true
	end

	SS.ShowMenuScene("gameMenuInGame")
	AfterSceneShown("gameMenuInGame", function()
		if not SelectPanelInMenu(entry.panel) then
			SS.Print(string.format(SS.L("COULD_NOT_OPEN_WHERE_LIVES"), where, entry.label))
			return
		end
		zo_callLater(function()
			ScrollToSetting(entry.panel, entry.system, entry.settingId)
		end, PANEL_SETTLE_MS)
	end)
	return true
end

local MENU_ENTRY_NAME = "SEARCH"

function SS.InjectMenuEntry(entries)
	if type(entries) ~= "table" then return false end
	for _, entry in ipairs(entries) do
		if entry.name == MENU_ENTRY_NAME then return false end
	end

	local data = {
		name = MENU_ENTRY_NAME,
		callback = function() SS.ShowBar() end,
	}

	local addons_name = GetString(SI_GAME_MENU_ADDONS)
	for position, entry in ipairs(entries) do
		if entry.name == addons_name then
			table.insert(entries, position + 1, data)
			return true
		end
	end

	table.insert(entries, data)
	return true
end

local GAMEPAD_MENU_ID = "APHSearch"
local GAMEPAD_MENU_ICON = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_search_64.dds"
local gamepad_menu_entry

local function GamepadMenuPosition()
	for index, entry in ipairs(ZO_MENU_ENTRIES) do
		if entry.id == "LibHarvensAddonSettings" then return index + 1 end
	end
	for index, entry in ipairs(ZO_MENU_ENTRIES) do
		if entry.id == ZO_MENU_MAIN_ENTRIES.ACTIVITY_FINDER then return index end
	end
	return #ZO_MENU_ENTRIES + 1
end

function SS.PlaceGamepadMenuEntry()
	if not gamepad_menu_entry then
		gamepad_menu_entry = ZO_GamepadEntryData:New(MENU_ENTRY_NAME, GAMEPAD_MENU_ICON)
		gamepad_menu_entry:SetIconTintOnSelection(true)
		gamepad_menu_entry:SetIconDisabledTintOnSelection(true)
		gamepad_menu_entry.id = GAMEPAD_MENU_ID
		gamepad_menu_entry.data = { name = MENU_ENTRY_NAME, activatedCallback = function() SS.ShowBar() end }
	end

	local current
	for index, entry in ipairs(ZO_MENU_ENTRIES) do
		if entry == gamepad_menu_entry then current = index end
	end
	if current then table.remove(ZO_MENU_ENTRIES, current) end
	local wanted = GamepadMenuPosition()
	table.insert(ZO_MENU_ENTRIES, wanted, gamepad_menu_entry)
	return current ~= wanted
end

local function HookGamepadMenu()
	SS.PlaceGamepadMenuEntry()
	MAIN_MENU_GAMEPAD:RefreshMainList()
	MAIN_MENU_GAMEPAD_SCENE:RegisterCallback("StateChange", function(_, state)
		if state ~= SCENE_SHOWING then return end
		if SS.PlaceGamepadMenuEntry() then MAIN_MENU_GAMEPAD:RefreshMainList() end
	end)
end

function HookGameMenu()
	local control = ZO_GameMenu_InGame
	local menu = control and control.gameMenu
	if not menu or menu.settings_search_hooked then return false end

	menu.settings_search_hooked = true
	ZO_PreHook(menu, "SubmitLists", function(_, entries)
		SS.InjectMenuEntry(entries)
	end)
	return true
end

function SS.ResetToDefaults()
	for key, value in pairs(DEFAULTS) do
		if type(value) == "table" then
			SS.saved[key] = ZO_ShallowTableCopy(value)
		else
			SS.saved[key] = value
		end
	end
	SS.WatchInventory()
	return true
end

function SS.StrandedSkillLines()
	local stranded = {}
	local manager = SKILLS_DATA_MANAGER
	if not manager or type(manager.SkillTypeIterator) ~= "function" then return stranded end

	for _, typeData in manager:SkillTypeIterator() do
		for _, lineData in typeData:SkillLineIterator() do
			if type(lineData.IsAdvised) == "function" and type(lineData.IsAvailable) == "function"
				and type(lineData.SetAdvised) == "function"
				and lineData:IsAdvised() and not lineData:IsAvailable() then
				stranded[#stranded + 1] = lineData
			end
		end
	end
	return stranded
end

function SS.SkillLineAdviceCommand(args)
	local stranded = SS.StrandedSkillLines()
	if #stranded == 0 then
		SS.Print(SS.L("NO_SKILL_LINES_ARE_FLAGGED_FOR"), true)
		return
	end

	local wanted = type(args) == "string" and args:lower():gsub("^%s*(.-)%s*$", "%1") or ""
	if wanted ~= "clear" then
		SS.Print(string.format(SS.L("SKILL_LINE_S_FLAGGED_BUT_NOT"), #stranded), true)
		for _, lineData in ipairs(stranded) do
			SS.Print("  " .. tostring(lineData:GetName()), true)
		end
		SS.Print(SS.L("RUN_FSSKILLLINES_CLEAR_TO_REMOVE_THEM"), true)
		return
	end

	local cleared = 0
	for _, lineData in ipairs(stranded) do
		lineData:SetAdvised(false)
		cleared = cleared + 1
	end
	SS.Print(string.format(SS.L("CLEARED_SKILL_LINE_S_RELOAD_THE"), cleared), true)
end

local function Init()
	LibAPH.RegisterAddonDependencies(SS.name, { "LibAPH" },
		{ "LibAddonMenu-2.0", "LibHarvensAddonSettings" })
	SS.saved = ZO_SavedVars:NewAccountWide("APHSearch", 1, GetWorldName() or "Default", DEFAULTS)
	SS.saved.recent = SS.saved.recent or {}

	LibAPH.RegisterKeybindDefaults("APHSearch", SS.saved, {
		APHSEARCH_TOGGLE = KEY_S,
	}, { APHSEARCH_TOGGLE = KEY_ALT })

	if GetDisplayName() == "@APHONlC" then
		SLASH_COMMANDS["/fsskilllines"] = SS.SkillLineAdviceCommand
	end

	local function OpenBar(args)
		if args and args ~= "" then
			SS.ShowBar(args)
			return
		end
		SS.ToggleBar()
	end

	SLASH_COMMANDS["/fs"] = OpenBar

	LibAPH.RunInitStages(SS.name, {
		function()
			HookGameMenu()
			HookGamepadMenu()
			SS.WatchTrigger()
		end,
		function()
			WatchAddonPanels()
			SS.WatchInventory()
			WatchFriends()
			WatchCollectibles()
			WatchLeaderboards()
		end,
		SS.BuildSettingsPanel,
		SS.StartPrebuild,
	})
end

function WatchAddonPanels()
	if type(CALLBACK_MANAGER) ~= "table" or type(CALLBACK_MANAGER.RegisterCallback) ~= "function" then
		return false
	end

	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function()
		SS.ClearIndex(SS.SCOPE_PANELS)
	end)
	return true
end

local ITEM_BAGS = { BAG_BACKPACK, BAG_VIRTUAL }
local ITEMS_NAMESPACE = SS.name .. "Items"

local function StaleItems() SS.ClearIndex(SS.SCOPE_ITEMS) end

function SS.WatchInventory()
	EVENT_MANAGER:UnregisterForEvent(ITEMS_NAMESPACE .. "Full", EVENT_INVENTORY_FULL_UPDATE)
	for _, bag in ipairs(ITEM_BAGS) do
		EVENT_MANAGER:UnregisterForEvent(ITEMS_NAMESPACE .. "Bag" .. bag, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
	end
	if not SS.IsScopeEnabled(SS.SCOPE_ITEMS) then return false end

	EVENT_MANAGER:RegisterForEvent(ITEMS_NAMESPACE .. "Full", EVENT_INVENTORY_FULL_UPDATE, StaleItems)
	for _, bag in ipairs(ITEM_BAGS) do
		local namespace = ITEMS_NAMESPACE .. "Bag" .. bag
		EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, StaleItems)
		EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, bag)
	end
	return true
end

function WatchFriends()
	local function Stale() SS.ClearIndex(SS.SCOPE_FRIENDS) end

	local namespace = SS.name .. "Friends"
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_FRIEND_ADDED, Stale)
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_FRIEND_REMOVED, Stale)
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_FRIEND_PLAYER_STATUS_CHANGED, Stale)
	return true
end

function WatchCollectibles()
	local manager = ZO_COLLECTIBLE_DATA_MANAGER
	if not manager or type(manager.RegisterCallback) ~= "function" then return false end

	manager:RegisterCallback("OnCollectionUpdated", function()
		for _, scope in ipairs({ SS.SCOPE_COLLECTIBLES, SS.SCOPE_ALLIES, SS.SCOPE_TOOLS, SS.SCOPE_EMOTES, SS.SCOPE_OUTFIT_STYLES }) do
			SS.ClearIndex(scope)
		end
	end)
	return true
end

function WatchLeaderboards()
	local scene = SCENE_MANAGER:GetScene("leaderboards")
	if not scene then return false end

	scene:RegisterCallback("StateChange", function(_, state)
		if state == SCENE_SHOWN then SS.ClearIndex(SS.SCOPE_LEADERBOARDS) end
	end)
	return true
end

EVENT_MANAGER:RegisterForEvent(SS.name, EVENT_ADD_ON_LOADED, function(_, name)
	if name ~= SS.name then return end
	EVENT_MANAGER:UnregisterForEvent(SS.name, EVENT_ADD_ON_LOADED)
	Init()
end)

SS.DEFAULTS = DEFAULTS
SS.MAX_RECENT = MAX_RECENT
