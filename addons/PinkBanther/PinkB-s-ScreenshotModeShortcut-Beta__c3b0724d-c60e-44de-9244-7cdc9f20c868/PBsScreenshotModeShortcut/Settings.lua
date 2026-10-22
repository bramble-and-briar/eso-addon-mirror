-- PB's ScreenshotModeShortcut -- the settings panel
--
-- LibHarvensAddonSettings is optional: without it every row here is reachable from /pbshot,
-- and the add-on does not care which way the value was changed. The panel is built once, on
-- the first player activation, because the library is not necessarily loaded at file scope.
--
-- Nothing in here does the work itself. Each row reads and writes through the accessors in
-- Main.lua, so a value changed from the panel and a value changed from a slash command go
-- down the same path -- including the one that puts the input layer back.
if not PBS_SCREENSHOT_MODE_SHORTCUT then
	return
end

local addon = PBS_SCREENSHOT_MODE_SHORTCUT

-- The library takes dropdown items as { name = <shown>, data = <value> } and hands the whole
-- item back to setFunction, so the stored value never has to be recovered from a translated
-- label. Built at panel-build time rather than at load: every name comes out of GetString.
local lists = {
	modes = {},
	modeByToken = {},
	holds = {},
	holdByMs = {},
}

local MODE_LABELS = {
	auto = "SI_PBSSMS_MODE_AUTO",
	scene = "SI_PBSSMS_MODE_SCENE",
	gui = "SI_PBSSMS_MODE_GUI",
}

local function BuildLists()
	for _, mode in ipairs(addon.MODES or {}) do
		local entry = { name = GetString(_G[MODE_LABELS[mode]]), data = mode }
		lists.modes[#lists.modes + 1] = entry
		lists.modeByToken[mode] = entry
	end
	for _, holdMs in ipairs(addon.QUICK_SHOT_HOLDS_MS or {}) do
		local entry = { name = string.format(GetString(SI_PBSSMS_HOLD_ITEM), holdMs / 1000), data = holdMs }
		lists.holds[#lists.holds + 1] = entry
		lists.holdByMs[holdMs] = entry
	end
end

local function AddHeading(settings, library, label)
	settings:AddSetting(
		{
			-- ST_SECTION draws a divider with a heading; older copies only have ST_LABEL, and
			-- the text reads as a heading either way.
			type = library.ST_SECTION or library.ST_LABEL,
			label = label
		}
	)
end

function addon:InitSettings()
	local library = LibHarvensAddonSettings
	if not library then
		return
	end

	BuildLists()

	local settings = library:AddAddon(self.title)
	if not settings then
		return
	end
	self.settingsControls = settings
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	settings:AddSetting(
		{
			type = library.ST_LABEL,
			label = GetString(SI_PBSSMS_EXPLANATION)
		}
	)

	-- ---- the shortcut ------------------------------------------------------------------
	AddHeading(settings, library, GetString(SI_PBSSMS_SECTION_SHORTCUT))

	settings:AddSetting(
		{
			type = library.ST_CHECKBOX,
			label = GetString(SI_PBSSMS_ENABLED),
			tooltip = GetString(SI_PBSSMS_ENABLED_TOOLTIP),
			default = self.DEFAULTS.enabled,
			getFunction = function()
				return self:Enabled()
			end,
			setFunction = function(value)
				self:SetEnabled(value)
			end
		}
	)

	settings:AddSetting(
		{
			type = library.ST_DROPDOWN,
			label = GetString(SI_PBSSMS_MODE),
			tooltip = GetString(SI_PBSSMS_MODE_TOOLTIP),
			items = lists.modes,
			default = (lists.modeByToken[self.DEFAULTS.mode] or {}).name,
			getFunction = function()
				local entry = lists.modeByToken[self:Mode()]
				return entry and entry.name or (lists.modeByToken[self.DEFAULTS.mode] or {}).name
			end,
			setFunction = function(combobox, name, item)
				self:SetMode(item.data)
			end,
			disable = function()
				-- Quick shot mode never opens either of these, so the row would be a lie.
				return self:QuickShot()
			end
		}
	)

	-- ---- quick shot --------------------------------------------------------------------
	AddHeading(settings, library, GetString(SI_PBSSMS_SECTION_QUICK))

	settings:AddSetting(
		{
			type = library.ST_CHECKBOX,
			label = GetString(SI_PBSSMS_QUICK),
			tooltip = GetString(SI_PBSSMS_QUICK_TOOLTIP),
			default = self.DEFAULTS.quickShot,
			getFunction = function()
				return self:QuickShot()
			end,
			setFunction = function(value)
				self:SetQuickShot(value)
			end
		}
	)

	settings:AddSetting(
		{
			type = library.ST_DROPDOWN,
			label = GetString(SI_PBSSMS_HOLD),
			tooltip = GetString(SI_PBSSMS_HOLD_TOOLTIP),
			items = lists.holds,
			default = (lists.holdByMs[self.DEFAULTS.quickShotHoldMs] or {}).name,
			getFunction = function()
				local entry = lists.holdByMs[self:QuickShotHoldMs()]
				return entry and entry.name or (lists.holdByMs[self.DEFAULTS.quickShotHoldMs] or {}).name
			end,
			setFunction = function(combobox, name, item)
				self:SetQuickShotHoldMs(item.data)
			end,
			disable = function()
				return not self:QuickShot()
			end
		}
	)

	settings:AddSetting(
		{
			type = library.ST_BUTTON,
			label = GetString(SI_PBSSMS_RUN_NOW),
			tooltip = GetString(SI_PBSSMS_RUN_NOW_TOOLTIP),
			buttonText = GetString(SI_PBSSMS_RUN_NOW_BUTTON),
			clickHandler = function()
				-- From inside the panel this reports "not on an enabled gamepad HUD", which is
				-- the honest answer: the chord is a HUD shortcut and the panel is not the HUD.
				local ok, why = self:Fire()
				self:Raw((ok and "entered: " or "failed: ") .. tostring(why))
			end
		}
	)

	settings:AddSetting(
		{
			type = library.ST_BUTTON,
			label = GetString(SI_PBSSMS_RESET_ROW),
			tooltip = GetString(SI_PBSSMS_RESET_ROW_TOOLTIP),
			buttonText = GetString(SI_PBSSMS_RESET_BUTTON),
			clickHandler = function()
				self:Command("reset")
			end
		}
	)
end
