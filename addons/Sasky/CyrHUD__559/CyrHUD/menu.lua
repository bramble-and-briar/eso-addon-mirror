-- This file is part of CyrHUD
--
-- (C) 2015 Scott Yeskie (Sasky)
--
-- This p.rogram is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

CyrHUD = CyrHUD or {}



CyrHUD.menuPanel = {
    type 			= "panel",
    name			= CyrHUD.addonVars.name,
    author 			= CyrHUD.addonVars.author,
    version			= CyrHUD.addonVars.version,
    website			= CyrHUD.addonVars.website,
    slashCommand 	= "/cyrhuds"
}

CyrHUD.menuOptions = {
	{
	    type = "header",
        name = GetString(SI_CAMPAIGNRULESETTYPE1),
	},
	{
        type = "checkbox",
        name = GetString(SI_ITEM_ACTION_USE).." CyrHUD",
        getFunc = function() return CyrHUD.cfg.enableInCyro end,
        setFunc = function(v) CyrHUD.cfg.enableInCyro = v CyrHUD.playerInit() end,
		default = true,
    },
    {
        type = "checkbox",
        name = GetString(SI_LFG_VIEW_VETERANCY),
        getFunc = function() return CyrHUD.cfg.showVeterancyCyro end,
        setFunc = function(v) CyrHUD.cfg.showVeterancyCyro = v CyrHUD:refresh() end,
		default = true,
    },
    {
        type = "checkbox",
        name = GetString(SI_CYRHUD_POPBAR),
        tooltip = GetString(SI_CYRHUD_POPBAR_INFO),
        getFunc = function() return CyrHUD.cfg.showPopBars end,
        setFunc = function(v) CyrHUD.cfg.showPopBars = v CyrHUD:reconfigureLabels() end,
		default = false,
    },
    -- {
        -- type = "checkbox",
        -- name = GetString(SI_CYRHUD_HIDE_KILLSDEATHS),
        -- tooltip = GetString(SI_CYRHUD_HIDE_KILLSDEATHS_INFO),
        -- getFunc = function() return CyrHUD.cfg.hideKillsDeaths or false end,
        -- setFunc = function(v) CyrHUD.cfg.hideKillsDeaths = v CyrHUD:reconfigureLabels() end
    -- },
    {
        type = "checkbox",
        name = GetString(SI_CYRHUD_HIDE_BRIDGESANDMILEGATES),
        tooltip = GetString(SI_CYRHUD_HIDE_BRIDGESANDMILEGATES_INFO),
        -- 05/07/2026 bug fix:
        -- getFunc read CyrHUD.cfg.hideBridgesAndMilegatesend (a typo, extra
        -- "end") while setFunc wrote to CyrHUD.cfg.hideBridgesAndMilegates
        -- (the correct key, the same one used elsewhere in CyrHUD.lua's
        -- scanKeeps/eventAttackChange). Since getFunc never read the key that
        -- was actually being saved, this checkbox always displayed as
        -- unchecked when the settings panel was reopened, even though the
        -- underlying setting was being saved and respected correctly.
        getFunc = function() return CyrHUD.cfg.hideBridgesAndMilegates end,
        setFunc = function(v) CyrHUD.cfg.hideBridgesAndMilegates = v CyrHUD:reconfigureLabels() end,
		default = false,
    },
	{
	    type = "header",
        name = GetString(SI_CAMPAIGNRULESETTYPE4),
	},
	{
        type = "checkbox",
        name = GetString(SI_ITEM_ACTION_USE).." CyrHUD",
        getFunc = function() return CyrHUD.cfg.enableInIC end,
        setFunc = function(v) CyrHUD.cfg.enableInIC = v CyrHUD.playerInit() end,
		default = true,
    },
    {
        type = "checkbox",
        name = GetString(SI_LFG_VIEW_VETERANCY),
        getFunc = function() return CyrHUD.cfg.showVeterancyIC end,
        setFunc = function(v) CyrHUD.cfg.showVeterancyIC = v CyrHUD:refresh() end,
		default = true,
    },
    {
        type = "checkbox",
        name = GetString(SI_CYRHUD_HIDE_IC),
        tooltip = GetString(SI_CYRHUD_HIDE_IC_INFO),
        getFunc = function() return CyrHUD.cfg.hideImpBattles end,
        setFunc = function(v) CyrHUD.cfg.hideImpBattles = v CyrHUD:reconfigureLabels() end,
		default = false,
    },
    {
        type = "checkbox",
        name = GetString(SI_GAMECAMERAACTIONTYPE24).." "..GetString(SI_CAMPAIGNRULESETTYPE4).." "..GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES501),
        tooltip = GetString(SI_GAMECAMERAACTIONTYPE24).." "..GetString(SI_CAMPAIGNRULESETTYPE4).." "..GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES501),
        getFunc = function() return CyrHUD.cfg.hidePatrollingHorrors end,
        setFunc = function(v) CyrHUD.cfg.hidePatrollingHorrors = v CyrHUD:refresh() CyrHUD:reconfigureLabels() end,
		default = false,
    },
	{
	    type = "header",
        name = GetString(SI_CAMPAIGNRULESETTYPE5),
	},
	{
        type = "checkbox",
        name = GetString(SI_ITEM_ACTION_USE).." CyrHUD",
        getFunc = function() return CyrHUD.cfg.enableInJerall end,
        setFunc = function(v) CyrHUD.cfg.enableInJerall = v CyrHUD.playerInit() end,
		default = true,
    },
    {
        type = "checkbox",
        name = GetString(SI_LFG_VIEW_VETERANCY),
        getFunc = function() return CyrHUD.cfg.showVeterancyJerall end,
        setFunc = function(v) CyrHUD.cfg.showVeterancyJerall = v CyrHUD:refresh() end,
		default = true,
    },
    {
        type = "checkbox",
        name = GetString(SI_CYRHUD_POPBAR),
        tooltip = GetString(SI_CYRHUD_POPBAR_INFO),
        getFunc = function() return CyrHUD.cfg.showPopBars end,
        setFunc = function(v) CyrHUD.cfg.showPopBars = v CyrHUD:reconfigureLabels() end,
		default = false,
    },
    {
        type = "checkbox",
        name = GetString(SI_CYRHUD_HIDE_PYRELORD),
        tooltip = GetString(SI_CYRHUD_HIDE_PYRELORD_INFO),
        getFunc = function() return CyrHUD.cfg.hidePyreLord end,
        setFunc = function(v) CyrHUD.cfg.hidePyreLord = v CyrHUD:refresh() CyrHUD:reconfigureLabels() end,
		default = false,
    },
	{ type = "submenu", name = GetString(SI_CYRHUD_QT),
			controls = {
							{
								type = "header",
								name = GetString(SI_CAMPAIGNRULESETTYPE1),
							},
							{
								type = "checkbox",
								name = GetString(SI_CYRHUD_QT_DEFAULT),
								tooltip = GetString(SI_CYRHUD_QT_TOOLTIP),
								getFunc = function() return CyrHUD.cfg.zosTrackerDisableCyro end,
								setFunc = function(v) CyrHUD.cfg.zosTrackerDisableCyro = v end,
								default = false,
							},
							{
								type = "checkbox",
								name = GetString(SI_CYRHUD_QT_WYKKYD),
								tooltip = GetString(SI_CYRHUD_QT_TOOLTIP),
								getFunc = function() return CyrHUD.cfg.ravTrackerDisableCyro end,
								setFunc = function(v) CyrHUD.cfg.ravTrackerDisableCyro = v end,
								default = false,
							},
							{
								type = "header",
								name = GetString(SI_CAMPAIGNRULESETTYPE4),
							},
							{
								type = "checkbox",
								name = GetString(SI_CYRHUD_QT_DEFAULT),
								tooltip = GetString(SI_CYRHUD_QT_TOOLTIP),
								getFunc = function() return CyrHUD.cfg.zosTrackerDisableIC end,
								setFunc = function(v) CyrHUD.cfg.zosTrackerDisableIC = v end,
								default = false,
							},
							{
								type = "checkbox",
								name = GetString(SI_CYRHUD_QT_WYKKYD),
								tooltip = GetString(SI_CYRHUD_QT_TOOLTIP),
								getFunc = function() return CyrHUD.cfg.ravTrackerDisableIC end,
								setFunc = function(v) CyrHUD.cfg.ravTrackerDisableIC = v end,
								default = false,
							},
							{
								type = "header",
								name = GetString(SI_CAMPAIGNRULESETTYPE5),
							},
							{
								type = "checkbox",
								name = GetString(SI_CYRHUD_QT_DEFAULT),
								tooltip = GetString(SI_CYRHUD_QT_TOOLTIP),
								getFunc = function() return CyrHUD.cfg.zosTrackerDisableJerall end,
								setFunc = function(v) CyrHUD.cfg.zosTrackerDisableJerall = v end,
								default = false,
							},
							{
								type = "checkbox",
								name = GetString(SI_CYRHUD_QT_WYKKYD),
								tooltip = GetString(SI_CYRHUD_QT_TOOLTIP),
								getFunc = function() return CyrHUD.cfg.ravTrackerDisableJerall end,
								setFunc = function(v) CyrHUD.cfg.ravTrackerDisableJerall = v end,
								default = false,
							},
			
			            },
	},		

    {
        type = "description",
        title = GetString(SI_CYRHUD_KEYBIND_HEADER),
        text = GetString(SI_CYRHUD_KEYBIND_DESC)
    },

}