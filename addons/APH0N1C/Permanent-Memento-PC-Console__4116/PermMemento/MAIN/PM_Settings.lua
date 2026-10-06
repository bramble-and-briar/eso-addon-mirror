--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
local PM_defaults = PM.defaults

function PM.update_settings_reference()
	if PM.char_saved and PM.char_saved.use_account_settings then
		PM.settings = PM.acct_saved
	else
		PM.settings = PM.char_saved
	end

	if not PM.settings then return end

	if type(PM.settings.ui) ~= "table" then
		PM.settings.ui = ZO_ShallowTableCopy(PM_defaults.ui)
	end
	if type(PM.settings.ui_menu) ~= "table" then
		PM.settings.ui_menu = ZO_ShallowTableCopy(PM_defaults.ui_menu)
	end
	if type(PM.settings.sync_module) ~= "table" then
		PM.settings.sync_module = ZO_ShallowTableCopy(PM_defaults.sync_module)
	end
	if PM.refresh_loop_event_registrations then PM.refresh_loop_event_registrations() end
	if type(PM.settings.csa_durations) ~= "table" then
		PM.settings.csa_durations = ZO_ShallowTableCopy(PM_defaults.csa_durations)
	end
	if PM.acct_saved and type(PM.acct_saved.learned_data) ~= "table" then
		PM.acct_saved.learned_data = {}
	end
	if PM.settings.favorites == nil then PM.ensure_table(PM.settings, "favorites") end

	if PM.settings.ui.scale == nil then
		PM.settings.ui.scale = (IsConsoleUI() and 1.0 or 1.0)
	end
	if PM.settings.ui_menu.scale == nil then
		PM.settings.ui_menu.scale = (IsConsoleUI() and 1.2 or 1.0)
	end

	PM.call_optional(PM.update_learned_count, "Loop module (update_learned_count)")
	PM.call_optional(PM.update_ui_anchor, "UI module (update_ui_anchor)")
	PM.call_optional(PM.toggle_ui_update, "UI module (toggle_ui_update)")
	PM.call_optional(PM.update_favorites_choices, "Menu module (update_favorites_choices)")
	PM.call_optional(PM.apply_spin_stop, "Loop module (apply_spin_stop)")
end
