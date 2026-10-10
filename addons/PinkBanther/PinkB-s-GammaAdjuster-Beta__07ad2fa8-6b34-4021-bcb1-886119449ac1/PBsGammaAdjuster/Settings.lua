-- PBS_GAMMA_ADJUSTER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_GAMMA_ADJUSTER then
	return
end

local addon = PBS_GAMMA_ADJUSTER

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
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSGA_EXPLANATION)
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_CHECKBOX,
			label = GetString(SI_PBSGA_RESTORE),
			tooltip = GetString(SI_PBSGA_RESTORE_TOOLTIP),
			default = self.accountDefaults.enabled,
			getFunction = function()
				return self.account.enabled ~= false
			end,
			setFunction = function(value)
				self.account.enabled = value
			end
		}
	)

	-- Does the same as /pbgamma resync, so a player without a keyboard can run it by hand.
	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_BUTTON,
			label = GetString(SI_PBSGA_NOW),
			tooltip = GetString(SI_PBSGA_NOW_TOOLTIP),
			buttonText = GetString(SI_PBSGA_NOW_BUTTON),
			clickHandler = function()
				self:RestoreNow("settings panel")
			end
		}
	)

	settings:AddSetting(
		{
			type = LibHarvensAddonSettings.ST_LABEL,
			label = GetString(SI_PBSGA_NOTE)
		}
	)
end
