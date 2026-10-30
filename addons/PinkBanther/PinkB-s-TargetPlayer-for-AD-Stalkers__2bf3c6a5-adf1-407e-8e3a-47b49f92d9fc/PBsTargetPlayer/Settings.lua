-- PBS_TARGET_PLAYER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_TARGET_PLAYER then
	return
end

local addon = PBS_TARGET_PLAYER

-- The panel is built from a fixed number of slots, not by adding and removing rows as players
-- come and go. LibHarvensAddonSettings can rebuild its list on the fly, but nothing on a
-- console has measured that here; a slot per player uses only what the other add-ons in this
-- family already do on a PS5 -- sections that open into a sub-list, a text box, a button and a
-- refresh from a button's handler.
--
-- Each slot is a section. The section's own label is the player, so the list reads as a list
-- of names at a glance. Inside: the ID, and a delete button.
--
-- Nothing is greyed out when a slot is empty. LibHarvensAddonSettings only re-evaluates
-- "disable" when the panel refreshes, and a text box does not refresh it: typing an ID into
-- an empty slot would leave the rows below it dead until the player backed out and came again.

local RESET_ARM_MS = 8000

local function AddSlot(self, settings, LibHarvensAddonSettings, slot)
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SECTION or LibHarvensAddonSettings.ST_LABEL,
			-- A function, so the label follows the saved data every time the list is drawn.
			label = function()
				return self:SlotLabel(slot)
			end,
			tooltip = GetString(SI_PBTP_SLOT_TOOLTIP)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_EDIT,
			label = GetString(SI_PBTP_ROW_ID),
			tooltip = GetString(SI_PBTP_ROW_ID_TOOLTIP),
			maxChars = self.MAX_ID_CHARS,
			-- "Reset to defaults" would otherwise empty the field, which is a deletion.
			ignoreDefault = true,
			getFunction = function()
				return self:GetPlayer(slot).id
			end,
			-- Called every time the box loses focus, changed or not. An empty box is a deletion;
			-- anything else that is refused (a duplicate) says why and the box shows the old
			-- value again, because the library re-reads getFunction right after this returns.
			setFunction = function(text)
				local ok, reason, other = self:SetPlayerId(slot, text)
				if not ok and reason == "duplicate" then
					self.Print(GetString(SI_PBTP_DUPLICATE), text, other)
				end
			end
		}
	)

	-- Evaluated when the entry is opened, not when the panel is built: it scans the friend list and
	-- the guild rosters (cached for ten seconds), which is not something to do for twenty entries
	-- at login.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = function()
				return string.format(GetString(SI_PBTP_ROW_WHERE_FORMAT), self:WhereText(slot))
			end,
			tooltip = GetString(SI_PBTP_ROW_WHERE_TOOLTIP)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBTP_ROW_DELETE),
			tooltip = GetString(SI_PBTP_ROW_DELETE_TOOLTIP),
			buttonText = GetString(SI_PBTP_ROW_DELETE_BUTTON),
			ignoreDefault = true,
			clickHandler = function()
				local p = self:GetPlayer(slot)
				if p.id ~= "" then
					self.Print(GetString(SI_PBTP_REMOVED), slot, p.id)
					self:ClearPlayer(slot)
				end
				-- The rows were drawn from the old values, so they have to be told to re-read
				-- them or the panel keeps showing the player that was just deleted.
				self:RefreshPanel()
			end
		}
	)
end

function addon:InitSettings()
	local LibHarvensAddonSettings = LibHarvensAddonSettings
	if not LibHarvensAddonSettings then
		return
	end

	local settings = LibHarvensAddonSettings:AddAddon(self.title)
	if not settings then
		return
	end
	self.settingsControls = settings
	-- No library-wide "reset to defaults": it would walk every row, and the only defaults here
	-- are "no players". Clearing the list is an explicit, confirmed button below.
	settings.allowDefaults = false
	settings.author = self.author
	settings.version = self.version

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBTP_EXPLANATION)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_ENABLED),
			tooltip = GetString(SI_PBTP_ENABLED_TOOLTIP),
			default = self.DEFAULTS.enabled,
			getFunction = function()
				return self:GetOption("enabled")
			end,
			setFunction = function(value)
				self:SetOption("enabled", value)
			end
		}
	)

	-- One mark for every registered player; the user picks which. The entries are the game's own
	-- target marker icons, listed by name because a list row cannot show the icon itself.
	-- getFunction never returns nil: a dropdown handed nil has nothing to select and falls back
	-- to showing its first item, which would look like the choice had reset itself.
	local markItems = {}
	local markNameByIndex = {}
	for index = 1, self.MAX_MARK do
		local name = GetString(_G["SI_PBTP_MARK_" .. index])
		markItems[#markItems + 1] = { name = name, data = index }
		markNameByIndex[index] = name
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_DROPDOWN,
			label = GetString(SI_PBTP_MARK),
			tooltip = GetString(SI_PBTP_MARK_TOOLTIP),
			items = markItems,
			default = markNameByIndex[self.DEFAULTS.mark],
			getFunction = function()
				return markNameByIndex[self:GetOption("mark")] or markNameByIndex[self.DEFAULTS.mark]
			end,
			setFunction = function(combobox, name, item)
				self:SetMark(item.data)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_ALERT),
			tooltip = GetString(SI_PBTP_ALERT_TOOLTIP),
			default = self.DEFAULTS.alert,
			getFunction = function()
				return self:GetOption("alert")
			end,
			setFunction = function(value)
				self:SetOption("alert", value)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_ALERT_SOUND),
			tooltip = GetString(SI_PBTP_ALERT_SOUND_TOOLTIP),
			default = self.DEFAULTS.sound,
			getFunction = function()
				return self:GetOption("sound")
			end,
			setFunction = function(value)
				self:SetOption("sound", value)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_CYRODIIL),
			tooltip = GetString(SI_PBTP_CYRODIIL_TOOLTIP),
			default = self.DEFAULTS.cyrodiil,
			getFunction = function()
				return self:GetOption("cyrodiil")
			end,
			setFunction = function(value)
				self:SetOption("cyrodiil", value)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_CLEANUP),
			tooltip = GetString(SI_PBTP_CLEANUP_TOOLTIP),
			default = self.DEFAULTS.cleanup,
			getFunction = function()
				return self:GetOption("cleanup")
			end,
			setFunction = function(value)
				self:SetOption("cleanup", value)
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_CYRO_ONLY),
			tooltip = GetString(SI_PBTP_CYRO_ONLY_TOOLTIP),
			default = self.DEFAULTS.cyrodiilOnly,
			getFunction = function()
				return self:GetOption("cyrodiilOnly")
			end,
			setFunction = function(value)
				self:SetOption("cyrodiilOnly", value)
			end
		}
	)

	-- No heading over the slots: each slot is itself a row that opens, so a heading would be a
	-- section with nothing under it.
	for slot = 1, self.MAX_PLAYERS do
		AddSlot(self, settings, LibHarvensAddonSettings, slot)
	end

	-- Everything below belongs to the last section. It gets a section of its own so it is not
	-- tucked inside the last slot.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_SECTION or LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBTP_SECTION_GENERAL)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBTP_BANNER),
			tooltip = GetString(SI_PBTP_BANNER_TOOLTIP),
			default = self.DEFAULTS.banner,
			getFunction = function()
				return self:GetOption("banner")
			end,
			setFunction = function(value)
				self:SetOption("banner", value)
			end
		}
	)

	-- Deleting everyone is the one destructive thing on this panel that a stray button press
	-- could do. It needs two presses within a few seconds; the first changes the label.
	local armedAt
	local function IsArmed()
		return armedAt ~= nil and GetGameTimeMilliseconds() - armedAt < RESET_ARM_MS
	end

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = function()
				return GetString(IsArmed() and SI_PBTP_RESET_CONFIRM or SI_PBTP_RESET)
			end,
			tooltip = GetString(SI_PBTP_RESET_TOOLTIP),
			buttonText = GetString(SI_PBTP_RESET_BUTTON),
			ignoreDefault = true,
			clickHandler = function()
				if IsArmed() then
					armedAt = nil
					self:ClearAll()
					self.Print(GetString(SI_PBTP_CLEARED))
				else
					armedAt = GetGameTimeMilliseconds()
				end
				self:RefreshPanel()
			end
		}
	)
end
