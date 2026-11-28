local addon = {
	name = "LT-VotansKeybinder",
	accountDefaults = {
		Keybindings = {}
	},
	isDirty = true,
	DefaultGlobalActionName = {
		["ACTION_BUTTON_3"] = true,
		["ACTION_BUTTON_4"] = true,
		["ACTION_BUTTON_5"] = true,
		["ACTION_BUTTON_6"] = true,
		["ACTION_BUTTON_7"] = true,
		["ACTION_BUTTON_8"] = true,
		["ACTION_BUTTON_9"] = true,
		["ASSIST_NEXT_TRACKED_QUEST"] = true,
		["AUTORUN"] = true,
		["CAMERA_ZOOM_IN"] = true,
		["CAMERA_ZOOM_OUT"] = true,
		["CHAT_REPLY_TO_LAST_WHISPER"] = true,
		["COMMAND_PET"] = true,
		["CYCLE_PREFERRED_ENEMY_TARGET"] = true,
		["DIALOG_CLOSE"] = true,
		["DIALOG_NEGATIVE"] = true,
		["DIALOG_PRIMARY"] = true,
		["DIALOG_SECONDARY"] = true,
		["GAME_CAMERA_INTERACT"] = true,
		["GAME_CAMERA_MOUSE_FREE_LOOK"] = true,
		["MOVE_BACKWARD"] = true,
		["MOVE_FORWARD"] = true,
		["MOVE_JUMPASCEND"] = true,
		["PLAYER_TO_PLAYER_INTERACT"] = true,
		["PLAYER_TO_PLAYER_INTERACT_ACCEPT"] = true,
		["PLAYER_TO_PLAYER_INTERACT_DECLINE"] = true,
		["ROLL_DODGE"] = true,
		["SHEATHE_WEAPON_TOGGLE"] = true,
		["SIEGE_FIRE"] = true,
		["SIEGE_PACK_UP"] = true,
		["SIEGE_RELEASE"] = true,
		["SPECIAL_MOVE_ATTACK"] = true,
		["SPECIAL_MOVE_BLOCK"] = true,
		["SPECIAL_MOVE_CROUCH"] = true,
		["SPECIAL_MOVE_INTERRUPT"] = true,
		["SPECIAL_MOVE_SPRINT"] = true,
		["SPECIAL_MOVE_WEAPON_SWAP"] = true,
		["SPECIAL_MOVE_WEAPON_SWAP_TO_SET_1"] = true,
		["SPECIAL_MOVE_WEAPON_SWAP_TO_SET_2"] = true,
		["START_CHAT_ENTER"] = true,
		["START_CHAT_SLASH"] = true,
		["TAKE_SCREENSHOT"] = true,
		["TOGGLE_ALLIANCE_WAR"] = true,
		["TOGGLE_CHAMPION"] = true,
		["TOGGLE_CHARACTER"] = true,
		["TOGGLE_COLLECTIONS_BOOK"] = true,
		["TOGGLE_CONTACTS"] = true,
		["TOGGLE_FIRST_PERSON"] = true,
		["TOGGLE_FULLSCREEN"] = true,
		["TOGGLE_GAME_CAMERA_UI_MODE"] = true,
		["TOGGLE_GROUP"] = true,
		["TOGGLE_GUILDS"] = true,
		["TOGGLE_ACTIVITY_FINDER"] = true,
		["TOGGLE_HELP"] = true,
		["TOGGLE_HUD_UI"] = true,
		["TOGGLE_GAMEPAD_MODE"] = true,
		["TOGGLE_NAMEPLATES"] = true,
		["TOGGLE_HEALTHBARS"] = true,
		["TOGGLE_INVENTORY"] = true,
		["TOGGLE_JOURNAL"] = true,
		["TOGGLE_MAIL"] = true,
		["TOGGLE_MAP"] = true,
		["TOGGLE_MARKET"] = true,
		["TOGGLE_MOUNT"] = true,
		["TOGGLE_NOTIFICATIONS"] = true,
		["TOGGLE_SHOW_INGAME_GUI"] = true,
		["TOGGLE_SKILLS"] = true,
		["TOGGLE_SYSTEM"] = true,
		["TOGGLE_WALK"] = true,
		["TURN_LEFT"] = true,
		["TURN_RIGHT"] = true,
		["UI_SHORTCUT_CYCLE_FOCUSED_QUEST"] = true,
		["UI_SHORTCUT_NEGATIVE"] = true,
		["UI_SHORTCUT_PRIMARY"] = true,
		["UI_SHORTCUT_QUICK_SLOTS"] = true,
		["UI_SHORTCUT_REPORT_PLAYER"] = true,
		["UI_SHORTCUT_SECONDARY"] = true,
		["UI_SHORTCUT_SHOW_QUEST_ON_MAP"] = true,
		["UI_SHORTCUT_TERTIARY"] = true,
		["USE_SYNERGY"] = true
	}
}

local unbindAllKeysFromAction
local bindKeyToAction

----- Helper for non-standard launcher -----
if IsProtectedFunction("UnbindAllKeysFromAction") then
	unbindAllKeysFromAction = function(...)
		CallSecureProtected("UnbindAllKeysFromAction", ...)
	end
	bindKeyToAction = function(...)
		CallSecureProtected("BindKeyToAction", ...)
	end
elseif not IsPrivateFunction("UnbindAllKeysFromAction") then
	unbindAllKeysFromAction = UnbindAllKeysFromAction
	bindKeyToAction = BindKeyToAction
else
	return
end

local wm = GetWindowManager()
local em = GetEventManager()
local KEYBIND_DATA_TYPE = 3
local KEYBINDING_MANAGER = KEYBOARD_KEYBINDING_MANAGER or KEYBINDING_MANAGER
assert(KEYBINDING_MANAGER, "LT-VotansKeybinder: KEYBINDING_MANAGER not found")

local keybindList = KEYBINDING_MANAGER.list
local orgHandleBindingsLoaded = KEYBINDING_MANAGER.HandleBindingsLoaded
local orgHandleBindingCleared = KEYBINDING_MANAGER.HandleBindingCleared
local orgHandleBindingSet = KEYBINDING_MANAGER.HandleBindingSet
local maxBindings = GetMaxBindingsPerAction()

----- Helper functions -----
local function CompareBinding(a, b)
	if a == b then
		return true
	end
	local GetActionBindingInfo, ZO_Keybindings_DoesKeyMatchAnyModifiers = GetActionBindingInfo, ZO_Keybindings_DoesKeyMatchAnyModifiers
	for bindIndex = 1, maxBindings do
		local keyCode, mod1, mod2, mod3, mod4 = GetActionBindingInfo(b.layerIndex, b.categoryIndex, b.actionIndex, bindIndex)
		local mod1a, mod2a, mod3a, mod4a =
			ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_CTRL, mod1, mod2, mod3, mod4) and KEY_CTRL or 0,
			ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_ALT, mod1, mod2, mod3, mod4) and KEY_ALT or 0,
			ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_SHIFT, mod1, mod2, mod3, mod4) and KEY_SHIFT or 0,
			ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_COMMAND, mod1, mod2, mod3, mod4) and KEY_COMMAND or 0
		local other = a[bindIndex]
		if not other then
			return false
		end
		if other.keyCode ~= keyCode or other.mod1 ~= mod1a or other.mod2 ~= mod2a or other.mod3 ~= mod3a or other.mod4 ~= mod4a then
			return false
		end
	end
	return true
end

local function HasBinding(b)
	local GetActionBindingInfo = GetActionBindingInfo
	for bindIndex = 1, maxBindings do
		local keyCode = GetActionBindingInfo(b.layerIndex, b.categoryIndex, b.actionIndex, bindIndex)
		if keyCode ~= 0 then
			return true
		end
	end
	return false
end

local function KeybindingsOfActionName(layerIndex, categoryIndex, actionIndex)
	local GetActionBindingInfo, ZO_Keybindings_DoesKeyMatchAnyModifiers = GetActionBindingInfo, ZO_Keybindings_DoesKeyMatchAnyModifiers
	local bindings = {}
	for bindIndex = 1, maxBindings do
		local keyCode, mod1, mod2, mod3, mod4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindIndex)
		bindings[bindIndex] = {
			keyCode = keyCode,
			mod1 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_CTRL, mod1, mod2, mod3, mod4) and KEY_CTRL or 0,
			mod2 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_ALT, mod1, mod2, mod3, mod4) and KEY_ALT or 0,
			mod3 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_SHIFT, mod1, mod2, mod3, mod4) and KEY_SHIFT or 0,
			mod4 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_COMMAND, mod1, mod2, mod3, mod4) and KEY_COMMAND or 0
		}
	end
	return bindings
end

----- UI -----
function addon:HandleBindingsLoaded()
	if addon.bindingsSyncronized then
		addon:SyncKeybindings()
		addon.isDirty = false
	else
		addon.isDirty = true
	end
end

function addon:HandleBindingCleared(layerIndex, categoryIndex, actionIndex, bindingIndex)
	addon.isDirty = true
	if addon.editMode then
		local bind = {
			keyCode = 0,
			mod1 = 0,
			mod2 = 0,
			mod3 = 0,
			mod4 = 0
		}
		local actionName, isRebindable, isHidden = GetActionInfo(layerIndex, categoryIndex, actionIndex)
		if not isHidden and addon.masterList[actionName] then
			addon.masterList[actionName][bindingIndex] = bind
			if addon.account.Keybindings[actionName] then
				addon.account.Keybindings[actionName][bindingIndex] = bind
			end
		end
	end
end

function addon:HandleBindingSet(layerIndex, categoryIndex, actionIndex, bindingIndex, keyCode, mod1, mod2, mod3, mod4)
	addon.isDirty = true
	if addon.editMode then
		local GetActionBindingInfo, ZO_Keybindings_DoesKeyMatchAnyModifiers = GetActionBindingInfo, ZO_Keybindings_DoesKeyMatchAnyModifiers
		local actionName, _, isHidden = GetActionInfo(layerIndex, categoryIndex, actionIndex)
		-- get validated mods
		keyCode, mod1, mod2, mod3, mod4 = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)

		local bind = {
			keyCode = keyCode,
			mod1 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_CTRL, mod1, mod2, mod3, mod4) and KEY_CTRL or 0,
			mod2 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_ALT, mod1, mod2, mod3, mod4) and KEY_ALT or 0,
			mod3 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_SHIFT, mod1, mod2, mod3, mod4) and KEY_SHIFT or 0,
			mod4 = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_COMMAND, mod1, mod2, mod3, mod4) and KEY_COMMAND or 0
		}
		local bindings = addon.account.Keybindings
		-- if action name is not in list, we do not support it. e.g. no localization string
		if addon.masterList[actionName] then
			addon.masterList[actionName][bindingIndex] = bind
			if bindings[actionName] then
				bindings[actionName][bindingIndex] = bind
			end
		end
	end
end

em:RegisterForEvent(
	addon.name,
	EVENT_KEYBINDING_SET,
	function(eventCode, ...)
		addon:HandleBindingSet(...)
	end
)
em:RegisterForEvent(
	addon.name,
	EVENT_KEYBINDING_CLEARED,
	function(eventCode, ...)
		addon:HandleBindingCleared(...)
	end
)
em:RegisterForEvent(
	addon.name,
	EVENT_KEYBINDINGS_LOADED,
	function(eventCode)
		em:UnregisterForUpdate(addon.name)
		em:RegisterForUpdate(
			addon.name,
			0,
			function()
				em:UnregisterForUpdate(addon.name)
				addon:HandleBindingsLoaded()
			end
		)
	end
)

local filterText = ""
local function HookBuildMasterList()
	local upperCache = {}
	local function TextFilter(localizedActionName)
		local upper = upperCache[localizedActionName]
		if not upper then
			upper = zo_strupper(localizedActionName)
			upperCache[localizedActionName] = upper
		end
		return zo_plainstrfind(upper, filterText)
	end

	local activeList = (KEYBOARD_KEYBINDING_MANAGER or KEYBINDING_MANAGER).list
	local orgBuildMasterList = activeList.BuildMasterList
	local orgGetKeybindData = KEYBINDINGS_MANAGER.GetKeybindData
	local isBuildList

	local function cleanSortName(str)
		if type(str) ~= "string" then return "" end
		str = str:gsub("|[tT].-|[tT]", "")
		str = str:gsub("|[cC]%x%x%x%x%x%x", ""):gsub("|[rR]", "")
		str = str:gsub("^[%s%[%]]+", "")
		return zo_strlower(str)
	end

		function activeList.BuildMasterList(...)
		isBuildList = true
		orgBuildMasterList(...)
		isBuildList = false
	end

	ZO_PostHook(activeList, "FilterScrollList", function(self)
		local scrollData = ZO_ScrollList_GetDataList(self.list)
		if not scrollData or #scrollData == 0 then return end

		local vanillaLayers = {
			[GetString(SI_KEYBINDINGS_LAYER_GENERAL)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_USER_INTERFACE_SHORTCUTS)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_SIEGE)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_DIALOG)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_HOUSING_EDITOR)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_BATTLEGROUNDS)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_SPECTATOR)] = true,
			[GetString(SI_KEYBINDINGS_LAYER_NOTIFICATIONS)] = true,
		}
		if SI_KEYBINDINGS_LAYER_TARGETING then
			vanillaLayers[GetString(SI_KEYBINDINGS_LAYER_TARGETING)] = true
		end
		if SI_KEYBINDINGS_LAYER_UTILITY_WHEEL then
			vanillaLayers[GetString(SI_KEYBINDINGS_LAYER_UTILITY_WHEEL)] = true
		end

		local vanillaCategories = {
			[GetString(SI_KEYBINDINGS_CATEGORY_MOVEMENT)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_COMBAT)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_INTERACTION)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_USER_INTERFACE)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_SIEGE)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_CAMERA)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_CHAT)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_SYSTEM)] = true,
			[GetString(SI_KEYBINDINGS_CATEGORY_HOUSING)] = true,
		}

		local vanillaBlocks = {}
		local addonBlocks = {}
		local currentBlock = nil
		local currentVanillaBlock = nil
		local inVanillaLayer = false

		for i = 1, #scrollData do
			local entry = scrollData[i]
			local data = entry.data and (entry.data.dataSource or (entry.data.GetDataSource and entry.data:GetDataSource()) or entry.data)

			if entry.typeId == 1 then
				local layerName = data and (data.layerName or data.name) or ""
				inVanillaLayer = vanillaLayers[layerName] or false

				if inVanillaLayer then
					currentVanillaBlock = {
						rows = { entry },
						isVanilla = true,
						sortKey = "",
						originalIndex = i,
					}
					vanillaBlocks[#vanillaBlocks + 1] = currentVanillaBlock
					currentBlock = currentVanillaBlock
				else
					currentVanillaBlock = nil
					currentBlock = {
						rows = { entry },
						sortKey = cleanSortName(layerName),
						originalIndex = i,
					}
					addonBlocks[#addonBlocks + 1] = currentBlock
				end
			elseif entry.typeId == 2 and inVanillaLayer then
				local catName = data and (data.categoryName or data.name) or ""
				if vanillaCategories[catName] and currentVanillaBlock then
					currentBlock = currentVanillaBlock
					currentBlock.rows[#currentBlock.rows + 1] = entry
				else
					currentBlock = {
						rows = { entry },
						sortKey = cleanSortName(catName),
						originalIndex = i,
					}
					addonBlocks[#addonBlocks + 1] = currentBlock
				end
			else
				if currentBlock then
					if not currentBlock.isVanilla and currentBlock.sortKey == "" and entry.typeId == 3 and data then
						currentBlock.sortKey = cleanSortName(data.localizedActionName or data.actionName or "")
					end
					currentBlock.rows[#currentBlock.rows + 1] = entry
				else
					vanillaBlocks[#vanillaBlocks + 1] = { rows = { entry }, isVanilla = true, sortKey = "", originalIndex = i }
				end
			end
		end

		table.sort(addonBlocks, function(a, b)
			if a.sortKey == b.sortKey then
				return a.originalIndex < b.originalIndex
			end
			return a.sortKey < b.sortKey
		end)

		ZO_ClearNumericallyIndexedTable(scrollData)
		for _, block in ipairs(vanillaBlocks) do
			for _, row in ipairs(block.rows) do
				scrollData[#scrollData + 1] = row
			end
		end
		for _, block in ipairs(addonBlocks) do
			for _, row in ipairs(block.rows) do
				scrollData[#scrollData + 1] = row
			end
		end
	end)


	local function createLayer(layerData)
		local newLayer = ZO_ShallowTableCopy(layerData)
		newLayer.categories = {}
		setmetatable(newLayer, getmetatable(layerData))
		return newLayer
	end

	function KEYBINDINGS_MANAGER.GetKeybindData(...)
		local filtered = orgGetKeybindData(...)

		if isBuildList and filterText ~= "" then
			local searchResults = {}
			for _, layerData in ipairs(filtered) do
				local newLayer
				for _, categoryData in ipairs(layerData.categories) do
					if categoryData.categoryName ~= "" and TextFilter(categoryData.categoryName) then
						newLayer = newLayer or createLayer(layerData)
						table.insert(newLayer.categories, categoryData)
					else
						local newCategory
						for _, action in ipairs(categoryData.actions) do
							local actionData = action:GetDataSource()
							if (actionData.localizedActionName ~= "" and TextFilter(actionData.localizedActionName)) or TextFilter(actionData.actionName) then
								newLayer = newLayer or createLayer(layerData)
								if not newCategory then
									newCategory = ZO_ShallowTableCopy(categoryData)
									newCategory.actions = {}
									setmetatable(newCategory, getmetatable(categoryData))
									table.insert(newLayer.categories, newCategory)
								end
								table.insert(newCategory.actions, action)
							end
						end
					end
				end
				if newLayer then
					table.insert(searchResults, newLayer)
				end
			end
			filtered = searchResults
		end

		return filtered
	end
end




local function HookKeybindingEventsHiding()
	addon.bindingsSyncronized = false
	addon.editMode = false
end
HookKeybindingEventsHiding()

local function HookKeybindsScrollList()
	local function ChangeKeybindGlobal(control, checkState)
		local data = ZO_ScrollList_GetData(control:GetParent())
		data = data:GetDataSource()

		if checkState == TRISTATE_CHECK_BUTTON_CHECKED then
			addon.account.Keybindings[data.actionName] = addon.masterList[data.actionName]
		elseif checkState == TRISTATE_CHECK_BUTTON_UNCHECKED then
			addon.account.Keybindings[data.actionName] = nil
		end
	end

	local function ShowTooltip(control)
		ZO_Tooltips_ShowTextTooltip(control, RIGHT, GetString(SI_VOTANS_KEYBINDER_ACCOUNTWIDE))
	end

	local function CreateCheckBox(control)
		local checkBox = wm:CreateControlFromVirtual("$(parent)LT-VotansKeybindGlobal", control, "ZO_TriStateCheckButton")
		local primaryBind = control:GetNamedChild("PrimaryBind")
		checkBox:SetAnchor(RIGHT, primaryBind, LEFT, -5, 0)
		ZO_TriStateCheckButton_SetStateChangeFunction(checkBox, ChangeKeybindGlobal)
		checkBox:SetHandler("OnMouseEnter", ShowTooltip)
		checkBox:SetHandler("OnMouseExit", ZO_Tooltips_HideTextTooltip)
		local actionName = control:GetNamedChild("ActionName")
		primaryBind:ClearAnchors()
		primaryBind:SetAnchor(LEFT, nil, LEFT, 270, 0)
		actionName:ClearAnchors()
		actionName:SetAnchor(LEFT, nil, LEFT, 5, 0)
		actionName:SetDimensions(255, 29)
		actionName:SetAnchor(RIGHT, checkBox, LEFT, -5, 0)
		return checkBox
	end

	local orgsetupCallback = keybindList.list.dataTypes[KEYBIND_DATA_TYPE].setupCallback
	local function SetupRow(control, data, ...)
		orgsetupCallback(control, data, ...)
		local checkBox = control:GetNamedChild("LT-VotansKeybindGlobal")
		-- for merlight
		if not checkBox then
			checkBox = CreateCheckBox(control)
		end
		data = data:GetDataSource()
		local globalKeybindings = addon.account.Keybindings[data.actionName]
		local isAccountWide = globalKeybindings and CompareBinding(globalKeybindings, data)
		ZO_TriStateCheckButton_SetState(checkBox, isAccountWide and TRISTATE_CHECK_BUTTON_CHECKED or (globalKeybindings == nil and TRISTATE_CHECK_BUTTON_UNCHECKED or TRISTATE_CHECK_BUTTON_INDETERMINATE))
	end
	keybindList.list.dataTypes[KEYBIND_DATA_TYPE].setupCallback = SetupRow

	local orgFactory = keybindList.list.dataTypes[KEYBIND_DATA_TYPE].pool.m_Factory
	local function Factory(pool, ...)
		local control, b = orgFactory(pool, ...)
		CreateCheckBox(control)
		return control
	end
	keybindList.list.dataTypes[KEYBIND_DATA_TYPE].pool.m_Factory = Factory
	keybindList:SetLockedForUpdates(true)
end

function addon:CreateBindingList()
	self.masterList = {}
	local masterList = self.masterList
	local accountList = self.account.Keybindings

	local GetActionLayerInfo, GetActionLayerCategoryInfo, GetActionInfo = GetActionLayerInfo, GetActionLayerCategoryInfo, GetActionInfo
	for layerIndex = 1, GetNumActionLayers() do
		local _, numCategories = GetActionLayerInfo(layerIndex)
		for categoryIndex = 1, numCategories do
			local _, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
			for actionIndex = 1, numActions do
				local actionName = GetActionInfo(layerIndex, categoryIndex, actionIndex)
				masterList[actionName] = KeybindingsOfActionName(layerIndex, categoryIndex, actionIndex)
			end
		end
	end
end

local hookInstalled = false

function addon:HandleControlsPageOpened()
	local function OnStateChanged(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			if not hookInstalled then
				HookBuildMasterList()
				hookInstalled = true
				addon.isDirty = true
			end
			keybindList:SetLockedForUpdates(false)
			if addon.isDirty then
				local mgr = KEYBOARD_KEYBINDING_MANAGER or KEYBINDING_MANAGER
				mgr.list:BuildMasterList()
				mgr:RefreshList()
				addon.isDirty = false
			end



			addon:CreateBindingList()
			addon.editMode = true
		elseif newState == SCENE_FRAGMENT_HIDING then
			keybindList:SetLockedForUpdates(true)
			HookKeybindingEventsHiding()
		end
	end

	KEYBINDINGS_FRAGMENT:RegisterCallback("StateChange", OnStateChanged)
end





function addon:FirstRun()

	em:UnregisterForEvent(self.name, EVENT_PLAYER_ACTIVATED)
	local defaults = self.DefaultGlobalActionName
	local globalKeybindings = self.account.Keybindings

	local GetNumActionLayers, GetActionLayerInfo, GetActionLayerCategoryInfo, GetActionInfo, KeybindingsOfActionName = GetNumActionLayers, GetActionLayerInfo, GetActionLayerCategoryInfo, GetActionInfo, KeybindingsOfActionName

	for layerIndex = 1, GetNumActionLayers() do
		local _, numCategories = GetActionLayerInfo(layerIndex)
		for categoryIndex = 1, numCategories do
			local _, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
			for actionIndex = 1, numActions do
				local actionName = GetActionInfo(layerIndex, categoryIndex, actionIndex)
				if defaults[actionName] then
					globalKeybindings[actionName] = KeybindingsOfActionName(layerIndex, categoryIndex, actionIndex)
				end
			end
		end
	end
	addon.bindingsSyncronized = true
end

do
	local identifier = "LT-VOTANS_SYNCKEYBINDINGS"

	local function doSync()
		em:UnregisterForUpdate(identifier)
		local self = addon
		local globalKeybindings = self.account.Keybindings
		local GetActionInfo, GetNumActionLayers, GetActionLayerInfo, GetActionLayerCategoryInfo = GetActionInfo, GetNumActionLayers, GetActionLayerInfo, GetActionLayerCategoryInfo

		local current = {}
		local function CheckSync()
			local actionName, _, isHidden = GetActionInfo(current.layerIndex, current.categoryIndex, current.actionIndex)
			local bind
			if not isHidden and globalKeybindings[actionName] then
				local target = globalKeybindings[actionName]
				if not CompareBinding(target, current) then
					unbindAllKeysFromAction(current.layerIndex, current.categoryIndex, current.actionIndex)
					for bindingIndex = 1, #target do
						bind = target[bindingIndex]
						if bind.keyCode ~= 0 then
							bindKeyToAction(current.layerIndex, current.categoryIndex, current.actionIndex, bindingIndex, bind.keyCode, bind.mod1, bind.mod2, bind.mod3, bind.mod4)
						end
					end
				end
			end
		end

		for layerIndex = 1, GetNumActionLayers() do
			current.layerIndex = layerIndex
			local _, numCategories = GetActionLayerInfo(layerIndex)
			for categoryIndex = 1, numCategories do
				current.categoryIndex = categoryIndex
				local _, numActions = GetActionLayerCategoryInfo(layerIndex, categoryIndex)
				for actionIndex = 1, numActions do
					current.actionIndex = actionIndex
					CheckSync()
				end
			end
		end
		self.bindingsSyncronized = true
	end
	function addon:SyncKeybindings()
		em:UnregisterForUpdate(identifier)
		em:RegisterForUpdate(identifier, 0, doSync)
	end
end

function addon:ToggleShareState()
	local function AllShared(accountList, visibleActions)
		for i = 1, #visibleActions do
			if accountList[visibleActions[i]] == nil then
				return false
			end
		end
		return true
	end
	local list = ZO_ScrollList_GetDataList(keybindList.list)
	local visibleActions = {}
	for i = 1, #list do
		local entry = list[i]
		if entry.typeId >= KEYBIND_DATA_TYPE then
			local data = entry.data:GetDataSource()
			if data.actionName and HasBinding(data) then
				visibleActions[#visibleActions + 1] = data.actionName
			end
		end
	end

	if #visibleActions == 0 then
		return
	end

	local accountList = self.account.Keybindings
	if AllShared(accountList, visibleActions) then
		for i = 1, #visibleActions do
			accountList[visibleActions[i]] = nil
		end
	else
		local masterList = self.masterList

		local bind
		for i = 1, #list do
			bind = list[i]
			if bind.typeId >= KEYBIND_DATA_TYPE then
				bind = bind.data:GetDataSource()
				if bind.actionName and (HasBinding(bind) or self.DefaultGlobalActionName[bind.actionName]) then
					masterList[bind.actionName] = KeybindingsOfActionName(bind.layerIndex, bind.categoryIndex, bind.actionIndex)
					accountList[bind.actionName] = masterList[bind.actionName]
				end
			end
		end
	end
	keybindList:RefreshVisible()
end

do
	local identifier = "LT_VOTANS_KEYBINDER_FILTER_CHANGED"
	local function DoUpdate()
		em:UnregisterForUpdate(identifier)
		filterText = zo_strupper(addon.searchBox:GetText())
		local mgr = KEYBOARD_KEYBINDING_MANAGER or KEYBINDING_MANAGER
		mgr.list:BuildMasterList()
		mgr.list:RefreshFilters()
	end

	function addon:FilterTextChanged()
		em:UnregisterForUpdate(identifier)
		em:RegisterForUpdate(identifier, 200, DoUpdate)
	end
end

local glass = " |t40:40:/esoui/art/tutorial/gamepad/gp_inventory_trait_not_researched_icon.dds|t"
local function setDefaultText(control, text)
	control:SetDefaultText(text)
end

local function SetupControl()
	local templateName = "ZO_InventorySearchTemplate"
	local bagSearchBg = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)LT_VotansKeybinderSearch", ZO_Keybindings, templateName)

	local bagSearch = bagSearchBg:GetNamedChild("Box")
	local bagSearchTx = bagSearch:GetNamedChild("Text")
	addon.searchBox = bagSearch

	local textWidth = 264
	bagSearchBg:ClearAnchors()
	bagSearchBg:SetAnchor(TOPLEFT, ZO_Keybindings, TOPLEFT, 74, 38)
	bagSearchBg:SetDimensions(textWidth, 31)

	local closeButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, bagSearchBg, "ZO_CloseButton")
	local function LT_VotansKeybinderFocusGained(bagSearch, ...)
		setDefaultText(bagSearch, "")
		bagSearchBg:SetAlpha(0.25)
		bagSearchBg:SetWidth(textWidth)
		closeButton:SetDimensions(16, 16)
		closeButton:SetHidden(false)
		return false
	end
	local function LT_VotansKeybinderFocusLost(bagSearch, ...)
		if bagSearch:GetText() ~= "" then
			bagSearchBg:SetAlpha(0.25)
			bagSearchBg:SetWidth(textWidth)
		else
			bagSearchBg:SetAlpha(0)
			bagSearchBg:SetWidth(64)
			closeButton:SetHidden(true)
		end
		setDefaultText(bagSearch, glass)
		return false
	end
	local function LT_VotansKeybinderTextChanged(control, ...)
		if WINDOW_MANAGER:GetFocusControl() ~= bagSearch then
			return LT_VotansKeybinderFocusLost(control, ...)
		end
		return false
	end
	local function LT_VotansKeybinderCloseClick(control, ...)
		bagSearch:SetText("")
		PlaySound(SOUNDS.DEFAULT_CLICK)
	end

	closeButton:ClearAnchors()
	closeButton:SetAnchor(TOPLEFT, bagSearch, TOPRIGHT, 0, 4)
	closeButton:SetHidden(true)
	closeButton:SetHandler("OnMouseDown", LT_VotansKeybinderCloseClick)
	closeButton:SetInheritAlpha(false)

	bagSearchBg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 32, 4)
	bagSearchBg:SetInsets(1, 1, 1, 1)
	bagSearch:ClearAnchors()
	bagSearch:SetAnchor(TOPLEFT, nil, TOPLEFT, 4, 4)
	bagSearch:SetAnchor(BOTTOMRIGHT, nil, BOTTOMRIGHT, -20, -4)
	bagSearch:SetInheritAlpha(false)
	bagSearch:SetEditEnabled(true)
	setDefaultText(bagSearch, glass)
	if bagSearchTx then
		bagSearchTx:ClearAnchors()
		bagSearchTx:SetAnchorFill()
	else
		bagSearch:SetDefaultTextColor(1, 1, 1, 1)
	end
	LT_VotansKeybinderFocusLost(bagSearch)

	bagSearch:SetHandler(
		"OnEscape",
		function(control)
			control:LoseFocus()
			control:SetText("")
		end
	)

	bagSearch:SetHandler(
		"OnTextChanged",
		function(control)
			ZO_EditDefaultText_OnTextChanged(control)
			addon:FilterTextChanged()
		end
	)

	bagSearch:SetHandler(
		"OnEnter",
		function(control)
			control:LoseFocus()
		end
	)

	ZO_PreHookHandler(bagSearch, "OnFocusGained", LT_VotansKeybinderFocusGained)
	ZO_PreHookHandler(bagSearch, "OnFocusLost", LT_VotansKeybinderFocusLost)
	ZO_PreHookHandler(bagSearch, "OnTextChanged", LT_VotansKeybinderTextChanged)
end

function addon:KeepBindButtonEnabled()
	local orgEnabled = BIND_KEY_DIALOG.control.bindButton.SetEnabled
	function BIND_KEY_DIALOG.control.bindButton.SetEnabled(self, enabled)
		return orgEnabled(self, true)
	end
end


function addon:Initialize()

	addon.isDirty = true
	self:HandleControlsPageOpened()
		em:RegisterForEvent(self.name .. "_SORT_HOOK", EVENT_PLAYER_ACTIVATED, function()
		em:UnregisterForEvent(self.name .. "_SORT_HOOK", EVENT_PLAYER_ACTIVATED)
		if not hookInstalled then
			HookBuildMasterList()
			hookInstalled = true
			addon.isDirty = true
		end
	end)

	if next(addon.account.Keybindings) == nil then

		em:RegisterForEvent(
			self.name,
			EVENT_PLAYER_ACTIVATED,
			function()
				self:FirstRun()
			end
		)
	elseif IsUnitInCombat("player") then 
		em:RegisterForEvent(
			self.name,
			EVENT_PLAYER_COMBAT_STATE,
			function(eventCode, inCombat)
				if not inCombat then
					em:UnregisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE)
					self:SyncKeybindings()
				end
			end
		)
	else
		self:SyncKeybindings()
	end

	local control = wm:CreateControlFromVirtual("$(parent)KeybinderToggle", ZO_Keybindings, "ZO_DialogButton")
	control:SetAnchor(TOPLEFT, ZO_KeybindingsLoadGamepadDefaults, TOPRIGHT, 15, 0)
	control.nameLabel:SetDimensionConstraints(0, 0, 200, 0)
	ZO_KeybindButtonTemplate_Setup(
		control,
		"LT_VOTANS_KEYBINDER_TOGGLE",
		function()
			self:ToggleShareState()
		end,
		GetString(SI_VOTANS_KEYBINDER_TOGGLE)
	)

	SetupControl()
	HookKeybindsScrollList()

	local function limitWidth(keybindButton)
		if not keybindButton then
			return
		end
		keybindButton.nameLabel:SetDimensionConstraints(0, 0, 200, 0)
	end
	limitWidth(ZO_KeybindingsLoadKeyboardDefaults)
	limitWidth(ZO_KeybindingsLoadGamepadDefaults)

	local function OnStateChanged(oldState, newState)
		if newState == SCENE_FRAGMENT_HIDING then
			RemoveActionLayerByName("KeybindWindow")
		end
	end
	KEYBINDINGS_FRAGMENT:RegisterCallback("StateChange", OnStateChanged)

	self:KeepBindButtonEnabled()
end

local function OnAddonLoaded(event, name)
	if name == addon.name then
		EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
		addon.account = ZO_SavedVars:New("LT_VotansKeybinder_Data", 1, nil, addon.accountDefaults, "Default", "$Machine", "$UserProfileWide")
		addon:Initialize()
	end
end


EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)

LT_VOTANS_KEYBINDER = addon

