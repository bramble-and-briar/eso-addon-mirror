-- FindMyStuff_Settings.lua
-- LibAddonMenu-2.0 settings panel. On PC it shows under Settings > Add-ons;
-- on console LAM r40+ converts it to a LibHarvensAddonSettings page.
-- Only uses control types the console converter supports (header,
-- description, checkbox, slider, button) and plain-string names, so the same
-- table also drives the gamepad screen's own Settings page.

FindMyStuff = FindMyStuff or {}
FindMyStuff.Settings = {}
local S = FindMyStuff.Settings

local function SV() return FindMyStuff.SavedVariables end
local function Default(key) return FindMyStuff.SettingDefaults[key] end

local function Changed()
	CALLBACK_MANAGER:FireCallbacks("FindMyStuff_SettingsChanged")
end

local function Checkbox(key, name, tooltip, onChange, extra)
	local c = {
		type = "checkbox",
		name = name,
		tooltip = tooltip,
		getFunc = function() return FindMyStuff.GetSetting(key) end,
		setFunc = function(v)
			SV()[key] = v
			if onChange then onChange(v) end
			Changed()
		end,
		default = Default(key),
	}
	if extra then for k, v in pairs(extra) do c[k] = v end end
	return c
end

local function Slider(key, name, tooltip, min, max, step, onChange)
	return {
		type = "slider",
		name = name,
		tooltip = tooltip,
		min = min, max = max, step = step,
		getFunc = function() return FindMyStuff.GetSetting(key) end,
		setFunc = function(v)
			SV()[key] = v
			if onChange then onChange(v) end
			Changed()
		end,
		default = Default(key),
	}
end

function S:ResetToDefaults()
	for key, value in pairs(FindMyStuff.SettingDefaults) do
		SV()[key] = value
	end
	if FindMyStuff.Window and FindMyStuff.Window.ApplyLock then FindMyStuff.Window.ApplyLock() end
	Changed()
end

-- The option list (LAM format), shared with the gamepad Settings page.
function S:BuildOptions()
	local options = {
		{
			type = "description",
			title = "Find My Stuff",
			text = IsConsoleUI()
				and "Open it from Main Menu > Find My Stuff, with L3 in a guild store, or with /fms."
				or "Open it with /fms, the keybind under Controls, or Main Menu > Find My Stuff in gamepad mode.",
		},
		{
			type = "button",
			name = "Open Find My Stuff",
			opensUI = true,
			tooltip = "Closes this menu and opens Find My Stuff.",
			func = function() S:OpenUIFromSettings() end,
			width = "half",
		},
		{
			type = "button",
			name = "Search Leads",
			opensUI = true,
			tooltip = "Closes this menu and opens the antiquity lead search.",
			func = function() S:OpenUIFromSettings("leads") end,
			width = "half",
		},

		-- Inventory ----------------------------------------------------------
		{ type = "header", name = "My Items" },
		Checkbox("autoScan", "Rescan after looting",
			"Rescan this character's bags a few seconds after you loot something. Bags are always scanned when you log in."),
		{
			type = "button",
			name = "Rescan bags now",
			tooltip = "Saves this character's bags, bank and craft bag right now.",
			func = function()
				FindMyStuff.ScanInventory()
				d("|cFF7700FindMyStuff:|r Inventory rescanned.")
			end,
			width = "half",
		},
		{
			type = "button",
			name = "Forget other characters",
			tooltip = "Deletes every saved inventory, then rescans the character you're on. Log in on your other characters to add them back.",
			isDangerous = true,
			warning = "This deletes the saved bags of all your other characters.",
			func = function()
				SV().charInventory = {}
				FindMyStuff.ScanInventory()
				d("|cFF7700FindMyStuff:|r Saved inventories cleared.")
				Changed()
			end,
			width = "half",
		},

		-- Guild traders ------------------------------------------------------
		{ type = "header", name = "Guild Traders" },
		Slider("traderPages", "Pages per guild",
			"How many result pages a trader scan reads from each guild store. Each page waits for the store's search cooldown. Add pages:N to a filter to override this.",
			1, 50, 1),
		Checkbox("traderChat", "Print matches in chat",
			"Also print each trader match in chat. Matches always show on the Guild Traders tab."),

		-- Chat & interface -----------------------------------------------------
		{ type = "header", name = "Chat & Interface" },
		Checkbox("showLogin", "Login message", "Print the \"FindMyStuff loaded\" line when you log in."),
		Slider("maxResults", "Chat lines per page",
			"How many results /fmslead prints at a time before asking you to add page:N.",
			25, 500, 25),
	}

	if not IsConsoleUI() then
		options[#options + 1] = Checkbox("windowLocked", "Lock window position",
			"Stops the Find My Stuff window from being dragged.",
			function() if FindMyStuff.Window then FindMyStuff.Window.ApplyLock() end end, { isPCOnly = true })
		options[#options + 1] = {
			type = "button",
			name = "Reset window position",
			tooltip = "Moves the Find My Stuff window back to the centre of the screen.",
			func = function()
				SV().windowPos = nil
				local win = FindMyStuffWindow
				if win then
					win:ClearAnchors()
					win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
				end
			end,
			width = "half",
			isPCOnly = true,
		}
	end
	return options
end

-- The settings menu is its own scene. Close it back to the world first, then
-- open our UI once the scene change has finished, so it isn't hidden behind it.
function S:OpenUIFromSettings(tab)
	if SCENE_MANAGER and SCENE_MANAGER.ShowBaseScene then
		SCENE_MANAGER:ShowBaseScene()
	end
	zo_callLater(function() FindMyStuff.ShowUI(tab) end, 250)
end

function S:Open()
	local LAM = LibAddonMenu2
	if LAM and self.panel and LAM.OpenToPanel then
		LAM:OpenToPanel(self.panel)
		return true
	end
	return false
end

function S:Build()
	local LAM = LibAddonMenu2
	if not LAM then return end
	local panelId = "FindMyStuffSettings"
	self.panelId = panelId
	self.panel = LAM:RegisterAddonPanel(panelId, {
		type = "panel",
		name = "Find My Stuff",
		displayName = "|cFF0000Find|r |cffff00My|r |c00ffffStuff!|r",
		author = "Vixen Hunny",
		version = FindMyStuff.Version,
		slashCommand = "/fmssettings",
		registerForRefresh = true,
		registerForDefaults = true,
		resetFunc = function() S:ResetToDefaults() end,
	})
	LAM:RegisterOptionControls(panelId, self:BuildOptions())
end

function FindMyStuff.InitSettings()
	S:Build()
end
