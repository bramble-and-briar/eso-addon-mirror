--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC

ALC.COMMAND_CATEGORIES = {
	{ title_key = "CAT_CLEANUP", cmds = {
		{ cmd = "/alcon", alias = "/alcenable", desc_key = "CMD_ALCON" },
		{ cmd = "/alcclean", alias = "/alccleanup", desc_key = "CMD_ALCCLEAN" },
		{ cmd = "/alccleanupmode", desc_key = "CMD_ALCCLEANUPMODE" },
		{ cmd = "/alcpoolreload", desc_key = "CMD_ALCPOOLRELOAD" },
		{ cmd = "/alcpoolconfirm", desc_key = "CMD_ALCPOOLCONFIRM", disabled_check = function() return not ALC.settings.auto_clear_pool_on_teleport end },
	}},
	{ title_key = "CAT_MEMORY_UI", cmds = {
		{ cmd = "/alcui", alias = "/alctoggleui", desc_key = "CMD_ALCUI", disabled_check = function() return ALC._modules.ui == false end },
		{ cmd = "/alclock", alias = "/alcuilock", desc_key = "CMD_ALCLOCK", disabled_check = function() return ALC._modules.ui == false or not ALC.settings.show_ui end },
		{ cmd = "/alcreset", alias = "/alcuireset", desc_key = "CMD_ALCRESET", disabled_check = function() return ALC._modules.ui == false or not ALC.settings.show_ui end },
	}},
	{ title_key = "CAT_GENERAL", cmds = {
		{ cmd = "/alccsa", alias = "/alctogglecsa", desc_key = "CMD_ALCCSA" },
		{ cmd = "/alclogs", alias = "/alcchatlogs", desc_key = "CMD_ALCLOGS", pc_only = true },
		{ cmd = "/alcwizard", desc_key = "CMD_ALCWIZARD", disabled_check = function() return ALC._modules.wizard == false end },
		{ cmd = "/alclibwarn", desc_key = "CMD_ALCLIBWARN" },
		{ cmd = "/alcbugreport", alias = "/alcbug", desc_key = "CMD_ALCBUGREPORT", pc_only = true },
		{ cmd = "/alcdelvars", alias = "/alcwipe", desc_key = "CMD_ALCDELVARS" },
	}},
	{ title_key = "CAT_MODULE_MANAGER", cmds = {
		{ cmd = "/alcunloadwizard", desc_key = "CMD_ALCUNLOADWIZARD" },
		{ cmd = "/alcunloadmenu", desc_key = "CMD_ALCUNLOADMENU" },
		{ cmd = "/alcunloadmigration", desc_key = "CMD_ALCUNLOADMIGRATION" },
	}}
}
