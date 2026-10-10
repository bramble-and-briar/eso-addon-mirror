AUI.Keybinding = {}

function AUI.Keybinding.Create()
	if AUI.Minimap.IsEnabled()then
		ZO_CreateStringId("SI_BINDING_NAME_AUI_Minimap_TOGGLE", AUI.L10n.GetString("toggle"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_zoom_IN", AUI.L10n.GetString("zoom_in"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_zoom_OUT", AUI.L10n.GetString("zoom_out"))
	end
	
	if AUI.Actionbar.IsEnabled() then
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_1", AUI.L10n.GetString("quickslot_1"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_2", AUI.L10n.GetString("quickslot_2"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_3", AUI.L10n.GetString("quickslot_3"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_4", AUI.L10n.GetString("quickslot_4"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_5", AUI.L10n.GetString("quickslot_5"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_6", AUI.L10n.GetString("quickslot_6"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_7", AUI.L10n.GetString("quickslot_7"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_8", AUI.L10n.GetString("quickslot_8"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_SELECT_PREVIOUS", AUI.L10n.GetString("quickslot_select_previous"))		
		ZO_CreateStringId("SI_BINDING_NAME_AUI_QUICKSLOT_SELECT_NEXT", AUI.L10n.GetString("quickslot_select_next"))		
	end
	
	if AUI.Combat.IsEnabled() then
		ZO_CreateStringId("SI_BINDING_NAME_AUI_SHOW_COMBAT_STATISTIC", AUI.L10n.GetString("show_combat_statistic"))
		ZO_CreateStringId("SI_BINDING_NAME_AUI_POST_ALL_COMBAT_STATISTIC", AUI.L10n.GetString("post_all_combat_statistic"))		
		ZO_CreateStringId("SI_BINDING_NAME_AUI_POST_HIGHEST_TARGET_COMBAT_STATISTIC", AUI.L10n.GetString("post_highest_target_combat_statistic"))		
	end
	
	if AUI.UnitFrames.Group.IsEnabled() then
		ZO_CreateStringId("SI_BINDING_NAME_AUI_REGROUP", AUI.L10n.GetString("regroup"))
	end
	
	ZO_CreateStringId("SI_BINDING_NAME_AUI_RELOADUI", AUI.L10n.GetString("reloadui"))
end