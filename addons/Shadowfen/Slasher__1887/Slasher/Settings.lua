local LAM = LibAddonMenu2
local SF = LibSFUtils
local SL=Slasher
local ASST=Slasher.assts
local HOLS=Slasher.holiday_items

local L = GetString

--cache data for dropdown:
local bankers = {
	choices = {
		L(SL_BANKER_SHOWNAME_ORIG),
		L(SL_BANKER_SHOWNAME_ALFIQ),
		L(SL_BANKER_SHOWNAME_CROW),
		L(SL_BANKER_SHOWNAME_CLOCK),
		L(SL_BANKER_SHOWNAME_MONST),
		L(SL_BANKER_SHOWNAME_ERI),
		L(SL_BANKER_SHOWNAME_CEL),
	},
	choicesValues = {
		267, 
		6376,
		8994,
		9743,
		11097,
		12415,
        13517,
	},
}

local merchants = {
	choices = { 
		L(SL_MERCHANT_SHOWNAME_ORIG), 
		L(SL_MERCHANT_SHOWNAME_ALFIQ),
		L(SL_MERCHANT_SHOWNAME_CROW),
		L(SL_MERCHANT_SHOWNAME_CLOCK),
		L(SL_MERCHANT_SHOWNAME_MONST),
		L(SL_MERCHANT_SHOWNAME_XYN),
		L(SL_MERCHANT_SHOWNAME_TER),
	},
	choicesValues = {
		301, 
		6378, 
		8995, 
		9744,
		11059,
		12414,
		13066,
	},
}

local decons = {
	choices = {
		L(SL_DECON_SHOWNAME_GIL), 
		L(SL_DECON_SHOWNAME_ADE),
		L(SL_DECON_SHOWNAME_SIL),
		L(SL_DECON_SHOWNAME_POR),
		L(SL_DECON_SHOWNAME_TZO),
	},
	choicesValues = {
		10184, 
		10617,
		13063,
		14018,
		11877,
	},
}

local fences = {
	choices = {
		L(SL_FENCE_SHOWNAME_PIR), 
		L(SL_FENCE_SHOWNAME_CAM), 
	},
	choicesValues = {
		300,
		14204,
	},
}
local armorer = {
	choices = {
		L(SL_ARMORER_SHOWNAME_GHR), 
		L(SL_ARMORER_SHOWNAME_ZUQ),
		L(SL_ARMORER_SHOWNAME_DRI),
		L(SL_ARMORER_SHOWNAME_VOK),
	},
	choicesValues = {
		9745,
		10618,
		11876,
		13518,
	},
}

local panelData = {
    type = "panel",
    name = SL.name,
	displayName = SL.displayName,
	author = SL.author,
	version = SL.version,
    slashCommand = "/slasher",
	registerForRefresh = true,
	registerForDefaults = true,
}

local optionsTable = {
		{
			type = "dropdown",
			name = SL_BANKER_DROPDOWN_NAME,
			scrollable = false,
			choices = bankers.choices,
			choicesValues = bankers.choicesValues,

			getFunc = function()
				if not SL.saved.banker then SL.saved.banker = 267 end
				return SL.saved.banker
			end,
			setFunc = function(value)
				SL.saved.banker = value
			end, 
			default = 267,
			width = "full",
		},
		{
			type = "dropdown",
			name = SL_MERCHANT_DROPDOWN_NAME,
			scrollable = false,
			choices = merchants.choices,
			choicesValues = merchants.choicesValues,

			getFunc = function()
				if not SL.saved.merchant then SL.saved.merchant = 301 end
				return SL.saved.merchant
			end,
			setFunc = function(value)
				SL.saved.merchant = value
			end, 
			default = 301,
			width = "full",
		},
		{
			type = "dropdown",
			name = SL_FENCE_DROPDOWN_NAME,
			scrollable = false,
			choices = fences.choices,
			choicesValues = fences.choicesValues,

			getFunc = function()
				if not SL.saved.fence then SL.saved.fence = 300 end
				return SL.saved.fence
			end,
			setFunc = function(value)
				SL.saved.fence = value
			end, 
			default = 300,
			width = "full",
		},
		{
			type = "dropdown",
			name = SL_DECON_DROPDOWN_NAME,
			scrollable = false,
			choices = decons.choices,
			choicesValues = decons.choicesValues,

			getFunc = function()
				if not SL.saved.decon then SL.saved.decon = 10184 end
				return SL.saved.decon
			end,
			setFunc = function(value)
				SL.saved.decon = value
			end, 
			default = 10184,
			width = "full",
		},

		{
			type = "dropdown",
			name = SL_ARMORER_DROPDOWN_NAME,
			scrollable = false,
			choices = armorer.choices,
			choicesValues = armorer.choicesValues,

			getFunc = function()
				if not SL.saved.armorer then SL.saved.armorer = 9745 end
				return SL.saved.armorer
			end,
			setFunc = function(value)
                d("changing armorer to "..value)
				SL.saved.armorer = value
			end, 
			default = 9745,
			width = "full",
		},

		--[[
		{
			type = "checkbox",
			name = SL_RESUMMON_COMPANION_NAME,
			tooltip = SL_RESUMMON_COMPANION_TT,
			getFunc = function() return SL.saved.resummon end,
			setFunc = function(x)
				SL.saved.resummon = x
			end,
			default = false,
		},  -- end checkbox
		--]]
}   -- end optionsTable

function SL.RegisterSettings()
   LAM:RegisterAddonPanel("SlasherOptions", panelData)
   LAM:RegisterOptionControls("SlasherOptions", optionsTable)
end
