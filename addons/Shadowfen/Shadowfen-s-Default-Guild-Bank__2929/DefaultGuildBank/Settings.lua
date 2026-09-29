local SGB = DefaultGuildBank
local LAM = LibAddonMenu2
local SF = LibSFUtils

local color = SF.hex

local function makePanelData(_name, _author, _version, _slash)
	local panelData = {
	   type = "panel",
	   name = _name,
	   displayName = SF.colors.gold(_name),
	   author = SF.colors.purple(_author),
	   version = SF.colors.gold(_version),
	   slashCommand = _slash,
	   registerForRefresh = true,
	}
	return panelData
end

local accountwide_section = {
		type = "checkbox",
		name = GetString(DGB_ACCOUNTWIDE),
		getFunc = function() return SGB.isAccountWide() end,
		setFunc = function(value) SGB.setCurrentSV(value) end,
		width = "full",
	}


--[[ SGB.RegisterSettings

    Creates and registers the LibAddonMenu2 settings panel for DefaultGuildBank.

    Builds the complete settings UI including the account-wide toggle,
    guild bank selection dropdown, and auto-enable checkbox. This function
    integrates with LAM2 (LibAddonMenu2) to present configuration options
    in the ESO Addons menu, allowing users to enable/disable the addon
    and choose which guild bank to use as their default.

    The settings panel is registered during onAddonLoaded(), before the
    player character is active. This is safe because settings callbacks
    only manipulate saved variables and do not depend on player inventory
    or guild membership state.

    @return nil
        No value is returned. Side effects are LAM panel registration and
        option control binding via LAM:RegisterAddonPanel() and
        LAM:RegisterOptionControls().
--]]
function SGB.RegisterSettings()

	if LAM == nil then return end

	local optionsTable = {
	-- accountwide section
		accountwide_section,

	-- Guild Bank Selection
		{
			type = "header",
			name = SF.GetIconized(DGB_SELECTION_NM, color.teal), -- or string id or function returning a string
			width = "full", --or "half" (optional)
		},
		{
			type = "checkbox",
			name = GetString(DGB_ENABLED),
			getFunc = function() return SGB.saved.dgb_enabled end,
			setFunc = function(value)
				SGB.saved.dgb_enabled = value
				if value == true then
					SGB.saved.dgb_enabled = true
					SGB.enabled()
				else
					SGB.disabled()
					SGB.saved.dgb_enabled = false
				end
				
				end,
			width = "full",
		},
        {
            type = "dropdown",
            name = DGB_GUILDS_NM,
            scrollable = false,
            choices = SF.GetActiveGuildNames(),
			choicesValues = SF.GetActiveGuildIds(),
			disabled = function()
				if SGB.saved.dgb_enabled == true then
					return false
				end
				return true
				end,
			getFunc = function()
				if not SGB.saved.defaultGuildId then
					_, SGB.saved.defaultGuildId = SF.SafeGetGuildName(1)
                end
				return SGB.saved.defaultGuildId
			end,
            setFunc = function(var)
                SGB.saved.defaultGuildId = var
            end,
            width = "full",
        },  -- end dropdown
	}

	local panelData = makePanelData(SGB.displayname, SGB.author, SGB.version, "/dgb")

	LAM:RegisterAddonPanel("DefaultGuildBankOptions", panelData)
	LAM:RegisterOptionControls("DefaultGuildBankOptions", optionsTable)
end
