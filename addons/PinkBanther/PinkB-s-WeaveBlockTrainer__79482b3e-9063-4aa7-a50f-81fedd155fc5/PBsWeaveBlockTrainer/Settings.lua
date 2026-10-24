-- PB's Weave & Block Trainer -- the settings panel (LibHarvensAddonSettings, optional)
--
-- PBS_WEAVEBLOCKTRAINER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_WEAVEBLOCKTRAINER then
	return
end

local addon = PBS_WEAVEBLOCKTRAINER

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

	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSWT_EXPLANATION) })

	Heading(GetString(SI_PBSWT_SECTION_METRONOME))
	Checkbox("metronome", SI_PBSWT_METRONOME, SI_PBSWT_METRONOME_TOOLTIP)
	Checkbox("sound", SI_PBSWT_SOUND, SI_PBSWT_SOUND_TOOLTIP)
	Slider("cycleMs", SI_PBSWT_CYCLE, SI_PBSWT_CYCLE_TOOLTIP, 900, 1200, 10)
	Slider("leadMs", SI_PBSWT_LEAD, SI_PBSWT_LEAD_TOOLTIP, 100, 500, 10)
	Checkbox("combatOnly", SI_PBSWT_COMBAT_ONLY, SI_PBSWT_COMBAT_ONLY_TOOLTIP)

	Heading(GetString(SI_PBSWT_SECTION_BLOCK))
	Checkbox("blockCue", SI_PBSWT_BLOCKCUE, SI_PBSWT_BLOCKCUE_TOOLTIP)
	Slider("windowMs", SI_PBSWT_WINDOW, SI_PBSWT_WINDOW_TOOLTIP, 100, 800, 10)

	Heading(GetString(SI_PBSWT_SECTION_POSITION))
	Slider("offsetX", SI_PBSWT_OFFSET_X, nil, -900, 900, 10)
	Slider("offsetY", SI_PBSWT_OFFSET_Y, nil, -500, 500, 10)

	settings:AddSetting(
		{
			type = LHAS.ST_BUTTON,
			label = GetString(SI_PBSWT_RESET),
			buttonText = GetString(SI_PBSWT_RESET_BUTTON),
			clickHandler = function()
				self:Reset()
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)
end
