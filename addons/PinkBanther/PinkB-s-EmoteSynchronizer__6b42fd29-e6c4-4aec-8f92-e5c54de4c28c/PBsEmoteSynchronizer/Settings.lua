-- PB's Emote Synchronizer -- the settings panel (LibHarvensAddonSettings, optional)
--
-- PBS_EMOTESYNCHRONIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_EMOTESYNCHRONIZER then
	return
end

local addon = PBS_EMOTESYNCHRONIZER

function addon:InitSettings()
	local LHAS = LibHarvensAddonSettings
	if not LHAS then
		return
	end

	local settings = LHAS:AddAddon(self.title)
	if not settings then
		return
	end
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	local function Heading(label)
		settings:AddSetting({ type = LHAS.ST_SECTION or LHAS.ST_LABEL, label = label })
	end

	local function Checkbox(key, label, tooltip)
		settings:AddSetting(
			{
				type = LHAS.ST_CHECKBOX,
				label = GetString(label),
				tooltip = GetString(tooltip),
				default = self.DEFAULTS[key],
				getFunction = function()
					return self.sv[key]
				end,
				setFunction = function(value)
					self:Set(key, value)
				end
			}
		)
	end

	local function Slider(key, label, tooltip, min, max, step)
		settings:AddSetting(
			{
				type = LHAS.ST_SLIDER,
				label = GetString(label),
				tooltip = tooltip and GetString(tooltip) or nil,
				min = min,
				max = max,
				step = step,
				default = self.DEFAULTS[key],
				getFunction = function()
					return self.sv[key]
				end,
				setFunction = function(value)
					self:Set(key, value)
				end
			}
		)
	end

	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSES_EXPLANATION) })

	Heading(GetString(SI_PBSES_SECTION_SYNC))
	Checkbox("enabled", SI_PBSES_ENABLED, SI_PBSES_ENABLED_TOOLTIP)
	Checkbox("send", SI_PBSES_SEND, SI_PBSES_SEND_TOOLTIP)
	Checkbox("follow", SI_PBSES_FOLLOW, SI_PBSES_FOLLOW_TOOLTIP)
	Checkbox("notify", SI_PBSES_NOTIFY, SI_PBSES_NOTIFY_TOOLTIP)
	Slider("leadMs", SI_PBSES_LEAD, SI_PBSES_LEAD_TOOLTIP, 0, 3000, 50)

	Heading(GetString(SI_PBSES_SECTION_TOOLS))
	settings:AddSetting(
		{
			type = LHAS.ST_BUTTON,
			label = GetString(SI_PBSES_PING_BUTTON),
			buttonText = GetString(SI_PBSES_PING_BUTTON_TEXT),
			clickHandler = function()
				self:Ping()
			end
		}
	)
	settings:AddSetting(
		{
			type = LHAS.ST_BUTTON,
			label = GetString(SI_PBSES_RESET),
			buttonText = GetString(SI_PBSES_RESET_BUTTON),
			clickHandler = function()
				self:Reset()
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)
end
