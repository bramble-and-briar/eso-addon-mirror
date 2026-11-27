-- Account-wide game settings.
-- ESO stores many Options on the server per character. This module keeps a
-- shared copy of chosen option categories in kpuiSavedVariables (account-wide)
-- and writes it to each character at login. The last change made on any
-- character becomes the shared copy.

local NAMESPACE = "KelaPadUIEnhanced_AccountSettings"
local CAPTURE_DEBOUNCE_NAME = NAMESPACE .. "_Capture"
local CAPTURE_DEBOUNCE_MS = 500
local SAVED_DATA_VERSION = 1
-- Fired by the settings panel checkboxes (see kpui_settings_gamepad.lua).
local KELA_ACCOUNT_SETTINGS_TOGGLED = "KELA_ACCOUNT_SETTINGS_TOGGLED"
-- Base-game gamepad Options scenes; leaving either one re-reads the categories.
local OPTIONS_SCENE_NAMES = { "gamepad_options_root", "gamepad_options_panel" }

-- Value kinds. Settings read through GetSetting/SetSetting:
local KIND_BOOL = "bool"            -- checkbox, stored "1"/"0"
local KIND_NUMBER = "number"        -- list choice, stored as an integer string
local KIND_FLOAT = "float"          -- slider, stored with the entry's format
-- Options the game reads through other APIs (entry.category is the chat category name):
local KIND_CHAT_COLOR = "chatColor"         -- Get/SetChatCategoryColor, stored "r,g,b"
local KIND_CHAT_BUBBLE = "chatBubble"       -- Is/SetChatBubbleCategoryEnabled, stored "1"/"0"
local KIND_GAMEPAD_CHAT_FONT = "gamepadChatFont" -- Get/SetGamepadChatFontSize

local DEFAULT_FLOAT_FORMAT = "%.2f"
local COLOR_FORMAT = "%.3f,%.3f,%.3f"

local function UsesGamepadChat()
	return ZO_ChatSystem_DoesPlatformUseGamepadChatSystem ~= nil and ZO_ChatSystem_DoesPlatformUseGamepadChatSystem()
end

-- Shorthands for the category tables below. Each entry names its system and
-- setting constant as strings; they are resolved through _G at runtime and also
-- form the saved key, so a renumbered or removed constant is skipped instead of
-- writing the wrong setting. `exists` hides an entry on platforms where the
-- game hides the option.
local function Bool(system, setting, exists)
	return { system = system, setting = setting, kind = KIND_BOOL, exists = exists }
end
local function Number(system, setting, exists)
	return { system = system, setting = setting, kind = KIND_NUMBER, exists = exists }
end
local function Float(system, setting, format)
	return { system = system, setting = setting, kind = KIND_FLOAT, format = format or DEFAULT_FLOAT_FORMAT }
end
local function ChatColor(category)
	return { category = category, kind = KIND_CHAT_COLOR }
end
local function ChatBubble(category)
	return { category = category, kind = KIND_CHAT_BUBBLE, exists = ZO_IsPCUI }
end

local function NameplatePair(prefix)
	return Number("SETTING_TYPE_NAMEPLATES", prefix), Number("SETTING_TYPE_NAMEPLATES", prefix .. "_HIGHLIGHT")
end

local CATEGORIES =
{
	combat =
	{
		settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_COMBAT,
		settings =
		{
			-- Heads-Up Display
			Number("SETTING_TYPE_UI", "UI_SETTING_SHOW_ACTION_BAR"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_ACTION_BAR_TIMERS"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_ACTION_BAR_BACK_ROW"),
			Number("SETTING_TYPE_UI", "UI_SETTING_SHOW_RESOURCE_BARS"),
			Number("SETTING_TYPE_UI", "UI_SETTING_RESOURCE_NUMBERS"),
			-- Active combat tips have no setting constant; the game uses the literal 0.
			{ system = "SETTING_TYPE_ACTIVE_COMBAT_TIP", settingValue = 0, kind = KIND_NUMBER },
			Bool("SETTING_TYPE_UI", "UI_SETTING_ULTIMATE_NUMBER"),
			-- Encounter Log
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_ENCOUNTER_LOG_APPEAR_ANONYMOUS", ZO_IsPCUI),
			-- Combat Text
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCROLLING_COMBAT_TEXT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_DAMAGE_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_DOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_HEALING_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_HOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_STATUS_EFFECTS_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_PET_DAMAGE_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_PET_DOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_PET_HEALING_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_OUTGOING_PET_HOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_DAMAGE_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_DOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_HEALING_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_HOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_STATUS_EFFECTS_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_PET_DAMAGE_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_INCOMING_PET_DOT_ENABLED"),
			Bool("SETTING_TYPE_COMBAT", "COMBAT_SETTING_SCT_SHOW_OVER_HEAL"),
			-- Buffs and Debuffs
			Number("SETTING_TYPE_BUFFS", "BUFFS_SETTING_ALL_ENABLED"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_BUFFS_ENABLED_FOR_SELF"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_DEBUFFS_ENABLED_FOR_SELF"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_DEBUFFS_ENABLED_FOR_TARGET_FROM_OTHERS"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_LONG_EFFECTS"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_PERMANENT_EFFECTS"),
			-- Not listed in the Options menu, but they gate other buff options and
			-- the HUD editor can change them.
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_BUFFS_ENABLED"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_BUFFS_ENABLED_FOR_TARGET"),
			Bool("SETTING_TYPE_BUFFS", "BUFFS_SETTING_DEBUFFS_ENABLED"),
		},
	},
	-- Inversion, sensitivity, assassination camera, screen shake and siege
	-- camera are saved in the client's UserSettings.txt, so every character on
	-- this PC already shares them; only the server-side options are listed.
	camera =
	{
		settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_CAMERA,
		settings =
		{
			Float("SETTING_TYPE_CAMERA", "CAMERA_SETTING_FIRST_PERSON_FIELD_OF_VIEW"),
			Float("SETTING_TYPE_CAMERA", "CAMERA_SETTING_FIRST_PERSON_HEAD_BOB"),
			Float("SETTING_TYPE_CAMERA", "CAMERA_SETTING_THIRD_PERSON_FIELD_OF_VIEW"),
			Float("SETTING_TYPE_CAMERA", "CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_POSITION_MULTIPLIER"),
			Float("SETTING_TYPE_CAMERA", "CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET"),
			Float("SETTING_TYPE_CAMERA", "CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET"),
		},
	},
	-- The text language is a client setting that needs a UI reload; it is left out.
	interface =
	{
		settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_INTERFACE,
		settings =
		{
			-- Heads-Up Display
			Number("SETTING_TYPE_UI", "UI_SETTING_PRIMARY_PLAYER_NAME_PC", ZO_IsPCUI),
			Number("SETTING_TYPE_UI", "UI_SETTING_PRIMARY_PLAYER_NAME_CONSOLE", ZO_IsConsoleOrGameCoreUI),
			Number("SETTING_TYPE_UI", "UI_SETTING_SHOW_RAID_LIVES"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_HOUSE_TRACKER"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_QUEST_TRACKER"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_AUTOMATIC_QUEST_TRACKING"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_QUEST_BESTOWER_INDICATORS"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_COMPASS_QUEST_GIVERS"),
			Number("SETTING_TYPE_UI", "UI_SETTING_COMPASS_ACTIVE_QUESTS"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_COMPASS_COMPANION"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_COMPASS_TARGET_MARKERS"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_COMPASS_DISTANCE_TRACKING"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_WEAPON_INDICATOR"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_ARMOR_INDICATOR"),
			-- Chat Bubbles
			Bool("SETTING_TYPE_CHAT_BUBBLE", "CHAT_BUBBLE_SETTING_ENABLED"),
			Float("SETTING_TYPE_CHAT_BUBBLE", "CHAT_BUBBLE_SETTING_SPEED_MODIFIER"),
			Bool("SETTING_TYPE_CHAT_BUBBLE", "CHAT_BUBBLE_SETTING_ENABLED_ONLY_FROM_CONTACTS"),
			Bool("SETTING_TYPE_CHAT_BUBBLE", "CHAT_BUBBLE_SETTING_ENABLED_FOR_LOCAL_PLAYER"),
			ChatBubble("CHAT_CATEGORY_SAY"),
			ChatBubble("CHAT_CATEGORY_YELL"),
			ChatBubble("CHAT_CATEGORY_WHISPER_INCOMING"),
			ChatBubble("CHAT_CATEGORY_WHISPER_OUTGOING"),
			ChatBubble("CHAT_CATEGORY_PARTY"),
			ChatBubble("CHAT_CATEGORY_EMOTE"),
			-- Performance
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_FRAMERATE", ZO_IsPCUI),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_LATENCY", ZO_IsPCUI),
			Bool("SETTING_TYPE_UI", "UI_SETTING_FRAMERATE_LATENCY_LOCK", ZO_IsPCUI),
		},
	},
	-- Filled below: most nameplate options come in shown/dimmed pairs.
	nameplates =
	{
		settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_NAMEPLATES,
		settings = {},
	},
	-- The keyboard chat text size and minimum opacity are stored per chat window
	-- by the keyboard chat, and restricted communication is an account control;
	-- they are left out.
	social =
	{
		settingId = KELA_SETTING_PANEL_ACCOUNT_SYNC_SOCIAL,
		settings =
		{
			-- Chat
			{ key = "GAMEPAD_CHAT_FONT_SIZE", kind = KIND_GAMEPAD_CHAT_FONT, exists = UsesGamepadChat },
			Bool("SETTING_TYPE_UI", "UI_SETTING_GAMEPAD_CHAT_HUD_ENABLED", UsesGamepadChat),
			Bool("SETTING_TYPE_LANGUAGE", "LANGUAGE_SETTING_USE_PROFANITY_FILTER"),
			-- Notifications
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_LEADERBOARD_NOTIFICATIONS"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_AUTO_DECLINE_DUEL_INVITES"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_AUTO_DECLINE_TRIBUTE_INVITES"),
			Number("SETTING_TYPE_UI", "UI_SETTING_SHOW_AVA_NOTIFICATIONS"),
			Number("SETTING_TYPE_UI", "UI_SETTING_SHOW_GUILD_KEEP_NOTICES"),
			Bool("SETTING_TYPE_UI", "UI_SETTING_SHOW_PVP_KILL_FEED_NOTIFICATIONS"),
			-- Chat Colors (the NPC color also covers NPC yell, whisper and emote)
			ChatColor("CHAT_CATEGORY_SAY"),
			ChatColor("CHAT_CATEGORY_YELL"),
			ChatColor("CHAT_CATEGORY_WHISPER_INCOMING"),
			ChatColor("CHAT_CATEGORY_WHISPER_OUTGOING"),
			ChatColor("CHAT_CATEGORY_PARTY"),
			ChatColor("CHAT_CATEGORY_ZONE"),
			ChatColor("CHAT_CATEGORY_ZONE_ENGLISH"),
			ChatColor("CHAT_CATEGORY_ZONE_FRENCH"),
			ChatColor("CHAT_CATEGORY_ZONE_GERMAN"),
			ChatColor("CHAT_CATEGORY_ZONE_JAPANESE"),
			ChatColor("CHAT_CATEGORY_ZONE_RUSSIAN"),
			ChatColor("CHAT_CATEGORY_ZONE_SPANISH"),
			ChatColor("CHAT_CATEGORY_ZONE_CHINESE_S"),
			ChatColor("CHAT_CATEGORY_MONSTER_SAY"),
			ChatColor("CHAT_CATEGORY_MONSTER_YELL"),
			ChatColor("CHAT_CATEGORY_MONSTER_WHISPER"),
			ChatColor("CHAT_CATEGORY_MONSTER_EMOTE"),
			ChatColor("CHAT_CATEGORY_EMOTE"),
			ChatColor("CHAT_CATEGORY_SYSTEM"),
			ChatColor("CHAT_CATEGORY_GUILD_1"),
			ChatColor("CHAT_CATEGORY_OFFICER_1"),
			ChatColor("CHAT_CATEGORY_GUILD_2"),
			ChatColor("CHAT_CATEGORY_OFFICER_2"),
			ChatColor("CHAT_CATEGORY_GUILD_3"),
			ChatColor("CHAT_CATEGORY_OFFICER_3"),
			ChatColor("CHAT_CATEGORY_GUILD_4"),
			ChatColor("CHAT_CATEGORY_OFFICER_4"),
			ChatColor("CHAT_CATEGORY_GUILD_5"),
			ChatColor("CHAT_CATEGORY_OFFICER_5"),
		},
	},
}

-- Shown/dimmed nameplate and health bar pairs, in Options menu order.
do
	local nameplates = CATEGORIES.nameplates.settings
	local function AddPairs(prefixes)
		for _, prefix in ipairs(prefixes) do
			local shown, dimmed = NameplatePair(prefix)
			table.insert(nameplates, shown)
			table.insert(nameplates, dimmed)
		end
	end
	-- Nameplates
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_ALL_NAMEPLATES"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_SHOW_PLAYER_TITLES"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_SHOW_PLAYER_GUILDS"))
	AddPairs({
		"NAMEPLATE_TYPE_PLAYER_NAMEPLATE",
		"NAMEPLATE_TYPE_GROUP_MEMBER_NAMEPLATES",
		"NAMEPLATE_TYPE_FRIENDLY_NPC_NAMEPLATES",
		"NAMEPLATE_TYPE_FRIENDLY_PLAYER_NAMEPLATES",
		"NAMEPLATE_TYPE_NEUTRAL_NPC_NAMEPLATES",
		"NAMEPLATE_TYPE_ENEMY_NPC_NAMEPLATES",
		"NAMEPLATE_TYPE_ENEMY_PLAYER_NAMEPLATES",
	})
	-- Health Bars
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_ALL_HEALTHBARS"))
	table.insert(nameplates, Number("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_HEALTHBAR_ALIGNMENT"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_HEALTHBAR_CHASE_BAR"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_HEALTHBAR_FRAME_BORDER"))
	AddPairs({
		"NAMEPLATE_TYPE_PLAYER_HEALTHBAR",
		"NAMEPLATE_TYPE_GROUP_MEMBER_HEALTHBARS",
		"NAMEPLATE_TYPE_FRIENDLY_NPC_HEALTHBARS",
		"NAMEPLATE_TYPE_FRIENDLY_PLAYER_HEALTHBARS",
		"NAMEPLATE_TYPE_NEUTRAL_NPC_HEALTHBARS",
		"NAMEPLATE_TYPE_ENEMY_NPC_HEALTHBARS",
		"NAMEPLATE_TYPE_ENEMY_PLAYER_HEALTHBARS",
	})
	-- Indicators and glows
	table.insert(nameplates, Number("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_ALLIANCE_INDICATORS"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_GROUP_INDICATORS"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_TARGET_MARKERS"))
	table.insert(nameplates, Float("SETTING_TYPE_IN_WORLD", "IN_WORLD_UI_SETTING_TARGET_MARKER_SIZE"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_RESURRECT_INDICATORS"))
	table.insert(nameplates, Bool("SETTING_TYPE_NAMEPLATES", "NAMEPLATE_TYPE_FOLLOWER_INDICATORS"))
	table.insert(nameplates, Float("SETTING_TYPE_IN_WORLD", "IN_WORLD_UI_SETTING_GLOW_THICKNESS", "%.3f"))
	table.insert(nameplates, Bool("SETTING_TYPE_IN_WORLD", "IN_WORLD_UI_SETTING_TARGET_GLOW_ENABLED"))
	table.insert(nameplates, Float("SETTING_TYPE_IN_WORLD", "IN_WORLD_UI_SETTING_TARGET_GLOW_INTENSITY", "%.3f"))
	table.insert(nameplates, Bool("SETTING_TYPE_IN_WORLD", "IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_ENABLED"))
	table.insert(nameplates, Float("SETTING_TYPE_IN_WORLD", "IN_WORLD_UI_SETTING_INTERACTABLE_GLOW_INTENSITY", "%.3f"))
end

-- Category keys in a fixed order (never rely on pairs order).
local CATEGORY_ORDER = { "combat", "camera", "interface", "nameplates", "social" }

-- Systems whose changes may arrive outside the Options menu (the HUD editor)
-- and fire EVENT_INTERFACE_SETTING_CHANGED.
local WATCHED_EVENT_SYSTEMS = { "SETTING_TYPE_UI", "SETTING_TYPE_BUFFS", "SETTING_TYPE_NAMEPLATES", "SETTING_TYPE_IN_WORLD", "SETTING_TYPE_CAMERA", "SETTING_TYPE_CHAT_BUBBLE" }

local appliedThisSession = false
local isApplying = false
local wasEnabled = {}

local function Log(level, message)
	local logger = KelaPadUI and KelaPadUI.log
	if logger then
		logger[level](logger, message)
	end
end

local function IsCategoryEnabled(categoryKey)
	return KelaGetSetting_Bool(SETTING_TYPE_KELA, CATEGORIES[categoryKey].settingId)
end

local function GetSavedRoot()
	local root = kpuiSavedVariables.accountGameSettings
	if type(root) ~= "table" or root.version ~= SAVED_DATA_VERSION then
		root = { version = SAVED_DATA_VERSION, categories = {} }
		kpuiSavedVariables.accountGameSettings = root
	end
	if type(root.categories) ~= "table" then
		root.categories = {}
	end
	return root
end

local function GetStoredCategory(categoryKey)
	local stored = GetSavedRoot().categories[categoryKey]
	if type(stored) == "table" and type(stored.values) == "table" then
		return stored
	end
	return nil
end

local function BoolCode(value)
	return value and "1" or "0"
end

-- Builds the saved key plus read and write functions for one entry. Returns nil
-- when the game does not define the constants or hides the option on this
-- platform. Values are codes: "1"/"0", integer strings, formatted numbers, or
-- "r,g,b" for colors.
local function ResolveEntry(entry)
	if type(entry.exists) == "function" and not entry.exists() then
		return nil
	end

	if entry.kind == KIND_GAMEPAD_CHAT_FONT then
		return entry.key,
			function() return tostring(GetGamepadChatFontSize()) end,
			function(value)
				local size = tonumber(value)
				SetGamepadChatFontSize(size)
				if GAMEPAD_CHAT_SYSTEM then
					GAMEPAD_CHAT_SYSTEM:SetFontSize(size)
				end
			end
	end

	if entry.kind == KIND_CHAT_COLOR or entry.kind == KIND_CHAT_BUBBLE then
		local category = _G[entry.category]
		if type(category) ~= "number" then
			Log("Warn", string.format("Account settings: skipped %s, not defined by the game", entry.category))
			return nil
		end
		if entry.kind == KIND_CHAT_COLOR then
			return "CHAT_COLOR|" .. entry.category,
				function() return string.format(COLOR_FORMAT, GetChatCategoryColor(category)) end,
				function(value)
					local r, g, b = string.match(value, "^([^,]+),([^,]+),([^,]+)$")
					r, g, b = tonumber(r), tonumber(g), tonumber(b)
					if r and g and b then
						SetChatCategoryColor(category, r, g, b)
					end
				end
		end
		return "CHAT_BUBBLE|" .. entry.category,
			function() return BoolCode(IsChatBubbleCategoryEnabled(category)) end,
			function(value) SetChatBubbleCategoryEnabled(category, value == "1") end
	end

	local systemId = _G[entry.system]
	local settingId
	local settingKey
	if entry.setting then
		settingId = _G[entry.setting]
		settingKey = entry.setting
	else
		settingId = entry.settingValue
		settingKey = tostring(entry.settingValue)
	end
	if type(systemId) ~= "number" or type(settingId) ~= "number" then
		Log("Warn", string.format("Account settings: skipped %s|%s, not defined by the game", entry.system, settingKey))
		return nil
	end
	local key = entry.system .. "|" .. settingKey

	if entry.kind == KIND_BOOL then
		return key,
			function() return BoolCode(GetSetting_Bool(systemId, settingId)) end,
			function(value) SetSetting(systemId, settingId, tostring(value == "1")) end
	end
	local format = entry.kind == KIND_FLOAT and entry.format or nil
	return key,
		function()
			local number = tonumber(GetSetting(systemId, settingId))
			if not number then
				return nil
			end
			return format and string.format(format, number) or tostring(number)
		end,
		function(value) SetSetting(systemId, settingId, value) end
end

local function ReadCategory(categoryKey)
	local values = {}
	for _, entry in ipairs(CATEGORIES[categoryKey].settings) do
		local key, read = ResolveEntry(entry)
		if key then
			values[key] = read()
		end
	end
	return values
end

local function CaptureCategory(categoryKey)
	GetSavedRoot().categories[categoryKey] =
	{
		values = ReadCategory(categoryKey),
		capturedAt = GetTimeStamp(),
	}
end

-- Writes every stored value that differs from this character's value.
local function ApplyCategory(categoryKey)
	local stored = GetStoredCategory(categoryKey)
	if not stored then
		return 0
	end
	local changed = 0
	isApplying = true
	for _, entry in ipairs(CATEGORIES[categoryKey].settings) do
		local key, read, write = ResolveEntry(entry)
		local storedValue = key and stored.values[key]
		if storedValue ~= nil then
			local currentValue = read()
			if currentValue ~= storedValue then
				write(storedValue)
				changed = changed + 1
				Log("Info", string.format("Account settings: %s %s -> %s", key, tostring(currentValue), storedValue))
				local afterValue = read()
				if afterValue ~= storedValue then
					Log("Warn", string.format("Account settings: %s did not take %s (reads %s)", key, storedValue, tostring(afterValue)))
				end
			end
		end
	end
	isApplying = false
	return changed
end

local function CaptureEnabledCategories()
	if not appliedThisSession or isApplying then
		return
	end
	for _, categoryKey in ipairs(CATEGORY_ORDER) do
		if IsCategoryEnabled(categoryKey) then
			CaptureCategory(categoryKey)
		end
	end
end

local function ScheduleCapture()
	if not appliedThisSession or isApplying then
		return
	end
	EVENT_MANAGER:UnregisterForUpdate(CAPTURE_DEBOUNCE_NAME)
	EVENT_MANAGER:RegisterForUpdate(CAPTURE_DEBOUNCE_NAME, CAPTURE_DEBOUNCE_MS, function()
		EVENT_MANAGER:UnregisterForUpdate(CAPTURE_DEBOUNCE_NAME)
		CaptureEnabledCategories()
	end)
end

local function ApplyEnabledCategoriesAtLogin()
	local totalChanged = 0
	for _, categoryKey in ipairs(CATEGORY_ORDER) do
		if IsCategoryEnabled(categoryKey) then
			if GetStoredCategory(categoryKey) then
				totalChanged = totalChanged + ApplyCategory(categoryKey)
			else
				-- Turned on but nothing stored yet (for example saved variables
				-- were cleared): this character becomes the shared copy.
				CaptureCategory(categoryKey)
			end
		end
	end
	if totalChanged > 0 then
		SendAllCachedSettingMessages()
	end
	appliedThisSession = true
end

local function OnPlayerActivated()
	EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED)
	ApplyEnabledCategoriesAtLogin()
end

local function OnInterfaceSettingChanged(_, systemId)
	for _, systemName in ipairs(WATCHED_EVENT_SYSTEMS) do
		if _G[systemName] == systemId then
			ScheduleCapture()
			return
		end
	end
end

-- Fired by the options list whenever a category checkbox shows a new value,
-- including when the list is first drawn, so act only on real changes.
local function OnCategoryToggled()
	for _, categoryKey in ipairs(CATEGORY_ORDER) do
		local enabled = IsCategoryEnabled(categoryKey)
		if enabled ~= wasEnabled[categoryKey] then
			wasEnabled[categoryKey] = enabled
			if enabled and appliedThisSession then
				-- Turning it on makes this character's values the shared copy.
				CaptureCategory(categoryKey)
			end
		end
	end
end

function KelaSetupAccountSettings()
	if KelaPadUI.KelaAccountSettingsInitialized then
		return
	end
	KelaPadUI.KelaAccountSettingsInitialized = true

	for _, categoryKey in ipairs(CATEGORY_ORDER) do
		wasEnabled[categoryKey] = IsCategoryEnabled(categoryKey)
	end

	CALLBACK_MANAGER:RegisterCallback(KELA_ACCOUNT_SETTINGS_TOGGLED, OnCategoryToggled)

	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_INTERFACE_SETTING_CHANGED, OnInterfaceSettingChanged)
	EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_PLAYER_DEACTIVATED, CaptureEnabledCategories)

	for _, sceneName in ipairs(OPTIONS_SCENE_NAMES) do
		local scene = SCENE_MANAGER:GetScene(sceneName)
		if scene then
			scene:RegisterCallback("StateChange", function(_, newState)
				if newState == SCENE_HIDDEN then
					CaptureEnabledCategories()
				end
			end)
		end
	end
end
