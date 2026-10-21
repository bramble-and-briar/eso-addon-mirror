-- Наборы значков для выбора: значки карты, эмблемы, символы интерфейса,
-- а также значки всех коллекций игры (собираются при первом открытии).
-- Все пути взяты из файлов интерфейса самой игры, поэтому они существуют.
local QTM  = AbyssQuest
local L    = QTM.L

local Icons = {}
QTM.Icons = Icons

Icons.TAB_PLACES       = 1
Icons.TAB_EMBLEMS      = 2
Icons.TAB_GLYPHS       = 3
Icons.TAB_COLLECTIBLES = 4

Icons.EMBLEMS = {
    "/esoui/art/campaign/overview_allianceicon_aldmeri.dds", "/esoui/art/campaign/overview_allianceicon_daggefall.dds",
    "/esoui/art/campaign/overview_allianceicon_ebonheart.dds", "/esoui/art/icons/constellation_apprentice.dds",
    "/esoui/art/icons/constellation_atronach.dds", "/esoui/art/icons/constellation_lady.dds",
    "/esoui/art/icons/constellation_lord.dds", "/esoui/art/icons/constellation_lovers.dds",
    "/esoui/art/icons/constellation_mage.dds", "/esoui/art/icons/constellation_ritual.dds",
    "/esoui/art/icons/constellation_serpent.dds", "/esoui/art/icons/constellation_shadow.dds",
    "/esoui/art/icons/constellation_stead.dds", "/esoui/art/icons/constellation_thief.dds",
    "/esoui/art/icons/constellation_tower.dds", "/esoui/art/icons/constellation_warrior.dds",
    "/esoui/art/icons/mapkey/mapkey_adventurezone.dds", "/esoui/art/icons/mapkey/mapkey_delve.dds",
    "/esoui/art/icons/mapkey/mapkey_dungeon.dds", "/esoui/art/icons/mapkey/mapkey_endlessdungeon.dds",
    "/esoui/art/icons/mapkey/mapkey_grouparea.dds", "/esoui/art/icons/mapkey/mapkey_groupdelve.dds",
    "/esoui/art/icons/mapkey/mapkey_groupinstance.dds", "/esoui/art/icons/mapkey/mapkey_groupmember.dds",
    "/esoui/art/icons/mapkey/mapkey_housing.dds", "/esoui/art/icons/mapkey/mapkey_mundus.dds",
    "/esoui/art/icons/mapkey/mapkey_player.dds", "/esoui/art/icons/mapkey/mapkey_raiddungeon.dds",
    "/esoui/art/icons/mapkey/mapkey_solo_dungeon.dds", "/esoui/art/icons/mapkey/mapkey_soloinstance.dds",
    "/esoui/art/icons/mapkey/mapkey_zonestory.dds", "/esoui/art/mappins/ava_artifact_almaruma.dds",
    "/esoui/art/mappins/ava_artifact_altadoon.dds", "/esoui/art/mappins/ava_artifact_chim.dds",
    "/esoui/art/mappins/ava_artifact_ghartok.dds", "/esoui/art/mappins/ava_artifact_mnem.dds",
    "/esoui/art/mappins/ava_artifact_nimohk.dds", "/esoui/art/mappins/ava_daedricartifact_volendrung_neutral.dds",
    "/esoui/art/mappins/ava_farm_neutral.dds", "/esoui/art/mappins/ava_imperialdistrict_neutral.dds",
    "/esoui/art/mappins/ava_largekeep_neutral.dds", "/esoui/art/mappins/ava_lumbermill_neutral.dds",
    "/esoui/art/mappins/ava_mine_neutral.dds", "/esoui/art/mappins/ava_outpost_neutral.dds",
    "/esoui/art/mappins/ava_town_neutral.dds", "/esoui/art/icons/battleground_score.dds",
    "/esoui/art/icons/crafing_universal_item.dds", "/esoui/art/icons/gift_box_003.dds",
    "/esoui/art/icons/icon_experience.dds", "/esoui/art/icons/quest_container_001.dds",
    "/esoui/art/icons/store_crowns.dds", "/esoui/art/icons/token_alliancechange.dds",
    "/esoui/art/icons/token_appearancechange.dds", "/esoui/art/icons/token_namechange.dds",
    "/esoui/art/icons/token_racechange.dds", "/esoui/art/icons/u50_bestowedtitle.dds",
}

Icons.GLYPHS = {
    "/esoui/art/bank/bank_tabicon_deposit_up.dds", "/esoui/art/bank/bank_tabicon_gold_up.dds",
    "/esoui/art/bank/bank_tabicon_withdraw_up.dds", "/esoui/art/bank/furniturevault_tabicon_deposit_up.dds",
    "/esoui/art/bank/furniturevault_tabicon_withdraw_up.dds", "/esoui/art/battlegrounds/battlegrounds_tabicon_battlegrounds_up.dds",
    "/esoui/art/cadwell/cadwell_indexicon_gold_up.dds", "/esoui/art/cadwell/cadwell_indexicon_silver_up.dds",
    "/esoui/art/campaign/campaign_tabicon_browser_up.dds", "/esoui/art/campaign/campaign_tabicon_summary_up.dds",
    "/esoui/art/campaign/campaign_tabicon_veterancy_up.dds", "/esoui/art/campaign/overview_indexicon_bonus_up.dds",
    "/esoui/art/campaign/overview_indexicon_emperor_up.dds", "/esoui/art/campaign/overview_indexicon_scoring_up.dds",
    "/esoui/art/campaign/overview_indexicon_vengeance_up.dds", "/esoui/art/charactercreate/charactercreate_audio_up.dds",
    "/esoui/art/charactercreate/charactercreate_bodyicon_up.dds", "/esoui/art/charactercreate/charactercreate_classicon_up.dds",
    "/esoui/art/charactercreate/charactercreate_faceicon_up.dds", "/esoui/art/charactercreate/charactercreate_femaleicon_up.dds",
    "/esoui/art/charactercreate/charactercreate_maleicon_up.dds", "/esoui/art/charactercreate/charactercreate_raceicon_up.dds",
    "/esoui/art/charactercreate/rotate_left_up.dds", "/esoui/art/charactercreate/rotate_right_up.dds",
    "/esoui/art/chatwindow/chat_addtab_up.dds", "/esoui/art/chatwindow/chat_cs_up.dds",
    "/esoui/art/chatwindow/chat_friendsonline_up.dds", "/esoui/art/chatwindow/chat_mail_up.dds",
    "/esoui/art/chatwindow/chat_notification_up.dds", "/esoui/art/chatwindow/chat_options_up.dds",
    "/esoui/art/collections/collections_categoryicon_locked_up.dds", "/esoui/art/collections/collections_categoryicon_unlocked_up.dds",
    "/esoui/art/collections/collections_tabicon_collectibles_up.dds", "/esoui/art/collections/collections_tabicon_dlc_up.dds",
    "/esoui/art/collections/collections_tabicon_housing_up.dds", "/esoui/art/collections/collections_tabicon_itemsets_up.dds",
    "/esoui/art/collections/collections_tabicon_outfitstyles_up.dds", "/esoui/art/collections/collections_tabicon_tributepatrons_up.dds",
    "/esoui/art/contacts/social_note_up.dds", "/esoui/art/contacts/tabicon_friends_up.dds",
    "/esoui/art/contacts/tabicon_ignored_up.dds", "/esoui/art/crafting/alchemy_tabicon_reagent_up.dds",
    "/esoui/art/crafting/alchemy_tabicon_solvent_up.dds", "/esoui/art/crafting/blueprints_tabicon_up.dds",
    "/esoui/art/crafting/designs_tabicon_up.dds", "/esoui/art/crafting/diagrams_tabicon_up.dds",
    "/esoui/art/crafting/enchantment_tabicon_aspect_up.dds", "/esoui/art/crafting/enchantment_tabicon_deconstruction_up.dds",
    "/esoui/art/crafting/enchantment_tabicon_essence_up.dds", "/esoui/art/crafting/enchantment_tabicon_potency_up.dds",
    "/esoui/art/crafting/formulae_tabicon_up.dds", "/esoui/art/crafting/jewelry_tabicon_icon_up.dds",
    "/esoui/art/crafting/jewelryset_tabicon_icon_up.dds", "/esoui/art/crafting/patterns_tabicon_up.dds",
    "/esoui/art/crafting/provisioner_indexicon_beer_up.dds", "/esoui/art/crafting/provisioner_indexicon_fillet_up.dds",
    "/esoui/art/crafting/provisioner_indexicon_fish_up.dds", "/esoui/art/crafting/provisioner_indexicon_furnishings_up.dds",
    "/esoui/art/crafting/provisioner_indexicon_meat_up.dds", "/esoui/art/crafting/reconstruct_tabicon_up.dds",
    "/esoui/art/crafting/retrait_tabicon_up.dds", "/esoui/art/crafting/schematics_tabicon_up.dds",
    "/esoui/art/crafting/scribing_tabicon_recent_up.dds", "/esoui/art/crafting/scribing_tabicon_scribing_up.dds",
    "/esoui/art/crafting/sketches_tabicon_up.dds", "/esoui/art/crafting/smithing_tabicon_armorset_up.dds",
    "/esoui/art/crafting/smithing_tabicon_creation_up.dds", "/esoui/art/crafting/smithing_tabicon_improve_up.dds",
    "/esoui/art/crafting/smithing_tabicon_refine_up.dds", "/esoui/art/crafting/smithing_tabicon_research_up.dds",
    "/esoui/art/crafting/smithing_tabicon_weaponset_up.dds", "/esoui/art/dye/dyes_categoryicon_up.dds",
    "/esoui/art/dye/dyes_tabicon_companion_up.dds", "/esoui/art/dye/dyes_tabicon_costumedye_up.dds",
    "/esoui/art/dye/dyes_tabicon_dye_up.dds", "/esoui/art/dye/dyes_tabicon_player_up.dds",
    "/esoui/art/dye/dyes_toolicon_erase_up.dds", "/esoui/art/dye/dyes_toolicon_fill_up.dds",
    "/esoui/art/dye/dyes_toolicon_paint_up.dds", "/esoui/art/dye/dyes_toolicon_sample_up.dds",
    "/esoui/art/dye/dyes_toolicon_setfill_up.dds", "/esoui/art/guild/guildheraldry_indexicon_background_up.dds",
    "/esoui/art/guild/guildheraldry_indexicon_crest_up.dds", "/esoui/art/guild/history/guildhistory_alliancewar_up.dds",
    "/esoui/art/guild/history/guildhistory_bankcurrency_up.dds", "/esoui/art/guild/history/guildhistory_bankitem_up.dds",
    "/esoui/art/guild/history/guildhistory_customize_up.dds", "/esoui/art/guild/history/guildhistory_purchases_up.dds",
    "/esoui/art/guild/history/guildhistory_roster_up.dds", "/esoui/art/guild/history/guildhistory_unlock_up.dds",
    "/esoui/art/guild/tabicon_heraldry_up.dds", "/esoui/art/guild/tabicon_history_up.dds",
    "/esoui/art/guild/tabicon_home_up.dds", "/esoui/art/guild/tabicon_ranks_up.dds",
    "/esoui/art/guild/tabicon_roster_up.dds", "/esoui/art/guildfinder/tabicon_recruitment_up.dds",
    "/esoui/art/help/help_tabicon_cs_up.dds", "/esoui/art/help/help_tabicon_emotes_up.dds",
    "/esoui/art/help/help_tabicon_feedback_up.dds", "/esoui/art/help/help_tabicon_itemassistance_up.dds",
    "/esoui/art/help/help_tabicon_overview_up.dds", "/esoui/art/help/help_tabicon_questassistance_up.dds",
    "/esoui/art/help/help_tabicon_stuck_up.dds", "/esoui/art/help/help_tabicon_trial_up.dds",
    "/esoui/art/help/help_tabicon_tutorial_up.dds", "/esoui/art/housing/housing_precisioncontrolicon_up.dds",
    "/esoui/art/inventory/inventory_currencytab_accountwide_up.dds", "/esoui/art/inventory/inventory_currencytab_oncharacter_up.dds",
    "/esoui/art/inventory/inventory_tabicon_1handed_up.dds", "/esoui/art/inventory/inventory_tabicon_2handed_up.dds",
    "/esoui/art/inventory/inventory_tabicon_all_up.dds", "/esoui/art/inventory/inventory_tabicon_appearance_up.dds",
    "/esoui/art/inventory/inventory_tabicon_armor_up.dds", "/esoui/art/inventory/inventory_tabicon_armorheavy_up.dds",
    "/esoui/art/inventory/inventory_tabicon_armorlight_up.dds", "/esoui/art/inventory/inventory_tabicon_armormedium_up.dds",
    "/esoui/art/inventory/inventory_tabicon_bait_up.dds", "/esoui/art/inventory/inventory_tabicon_bow_up.dds",
    "/esoui/art/inventory/inventory_tabicon_companion_up.dds", "/esoui/art/inventory/inventory_tabicon_consumables_up.dds",
    "/esoui/art/inventory/inventory_tabicon_container_up.dds", "/esoui/art/inventory/inventory_tabicon_craftbag_alchemy_up.dds",
    "/esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds", "/esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds",
    "/esoui/art/inventory/inventory_tabicon_craftbag_enchanting_up.dds", "/esoui/art/inventory/inventory_tabicon_craftbag_itemtrait_up.dds",
    "/esoui/art/inventory/inventory_tabicon_craftbag_jewelrycrafting_up.dds", "/esoui/art/inventory/inventory_tabicon_craftbag_provisioning_up.dds",
    "/esoui/art/inventory/inventory_tabicon_craftbag_stylematerial_up.dds", "/esoui/art/inventory/inventory_tabicon_craftbag_up.dds",
    "/esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds", "/esoui/art/inventory/inventory_tabicon_crafting_up.dds",
    "/esoui/art/inventory/inventory_tabicon_crown_up.dds", "/esoui/art/inventory/inventory_tabicon_damagestaff_up.dds",
    "/esoui/art/inventory/inventory_tabicon_furnishing_craftstation_up.dds", "/esoui/art/inventory/inventory_tabicon_furnishing_lighting_up.dds",
    "/esoui/art/inventory/inventory_tabicon_furnishing_material_up.dds", "/esoui/art/inventory/inventory_tabicon_furnishing_seating_up.dds",
    "/esoui/art/inventory/inventory_tabicon_furnishing_targetdummy_up.dds", "/esoui/art/inventory/inventory_tabicon_healstaff_up.dds",
    "/esoui/art/inventory/inventory_tabicon_items_up.dds", "/esoui/art/inventory/inventory_tabicon_junk_up.dds",
    "/esoui/art/inventory/inventory_tabicon_misc_up.dds", "/esoui/art/inventory/inventory_tabicon_quest_up.dds",
    "/esoui/art/inventory/inventory_tabicon_quickslot_up.dds", "/esoui/art/inventory/inventory_tabicon_recipe_up.dds",
    "/esoui/art/inventory/inventory_tabicon_repair_up.dds", "/esoui/art/inventory/inventory_tabicon_shield_up.dds",
    "/esoui/art/inventory/inventory_tabicon_siege_up.dds", "/esoui/art/inventory/inventory_tabicon_soulgem_up.dds",
    "/esoui/art/inventory/inventory_tabicon_tool_up.dds", "/esoui/art/inventory/inventory_tabicon_trash_up.dds",
    "/esoui/art/inventory/inventory_tabicon_trophy_up.dds", "/esoui/art/inventory/inventory_tabicon_vengeance_up.dds",
    "/esoui/art/inventory/inventory_tabicon_weapons_up.dds", "/esoui/art/inventory/inventory_upgradebag_up.dds",
    "/esoui/art/journal/journal_quests_tabicon_up.dds", "/esoui/art/journal/journal_rumors_tabicon_up.dds",
    "/esoui/art/journal/journal_tabicon_achievements_up.dds", "/esoui/art/journal/journal_tabicon_antiquities_up.dds",
    "/esoui/art/journal/journal_tabicon_cadwell_up.dds", "/esoui/art/journal/journal_tabicon_leaderboard_up.dds",
    "/esoui/art/journal/journal_tabicon_lorelibrary_up.dds", "/esoui/art/journal/journal_tabicon_quest_up.dds",
    "/esoui/art/journal/leaderboard_indexicon_ava_up.dds", "/esoui/art/journal/leaderboard_indexicon_challenge_up.dds",
    "/esoui/art/journal/leaderboard_indexicon_endlessdungeon_up.dds", "/esoui/art/journal/leaderboard_indexicon_raids_up.dds",
    "/esoui/art/journal/leaderboard_tabicon_guest_up.dds", "/esoui/art/journal/leaderboard_tabicon_home_up.dds",
    "/esoui/art/lfg/lfg_championdungeon_up.dds", "/esoui/art/lfg/lfg_groupfinder_additionalfilters_up.dds",
    "/esoui/art/lfg/lfg_groupfinder_refreshsearch_up.dds", "/esoui/art/lfg/lfg_indexicon_alliancewar_up.dds",
    "/esoui/art/lfg/lfg_indexicon_battlegrounds_up.dds", "/esoui/art/lfg/lfg_indexicon_dungeon_up.dds",
    "/esoui/art/lfg/lfg_indexicon_group_up.dds", "/esoui/art/lfg/lfg_indexicon_groupfinder_up.dds",
    "/esoui/art/lfg/lfg_indexicon_housetours_up.dds", "/esoui/art/lfg/lfg_indexicon_imperialcity_up.dds",
    "/esoui/art/lfg/lfg_indexicon_promotionalevents_up.dds", "/esoui/art/lfg/lfg_indexicon_writhingwall_up.dds",
    "/esoui/art/lfg/lfg_indexicon_zonestories_up.dds", "/esoui/art/lfg/lfg_normaldungeon_up.dds",
    "/esoui/art/lfg/lfg_veterandungeon_up.dds", "/esoui/art/mail/mail_tabicon_compose_up.dds",
    "/esoui/art/mail/mail_tabicon_inbox_up.dds", "/esoui/art/mainmenu/menubar_ava_up.dds",
    "/esoui/art/mainmenu/menubar_champion_up.dds", "/esoui/art/mainmenu/menubar_character_up.dds",
    "/esoui/art/mainmenu/menubar_collections_up.dds", "/esoui/art/mainmenu/menubar_crowncrates_up.dds",
    "/esoui/art/mainmenu/menubar_group_gold_up.dds", "/esoui/art/mainmenu/menubar_group_up.dds",
    "/esoui/art/mainmenu/menubar_guilds_up.dds", "/esoui/art/mainmenu/menubar_inventory_up.dds",
    "/esoui/art/mainmenu/menubar_journal_up.dds", "/esoui/art/mainmenu/menubar_mail_up.dds",
    "/esoui/art/mainmenu/menubar_map_up.dds", "/esoui/art/mainmenu/menubar_market_up.dds",
    "/esoui/art/mainmenu/menubar_notifications_up.dds", "/esoui/art/mainmenu/menubar_skills_up.dds",
    "/esoui/art/mainmenu/menubar_social_up.dds", "/esoui/art/mainmenu/menubar_tamrieltomes_up.dds",
    "/esoui/art/mounts/tabicon_ridingskills_up.dds", "/esoui/art/notifications/notification_help_up.dds",
    "/esoui/art/progression/addpoints_up.dds", "/esoui/art/progression/morph_up.dds",
    "/esoui/art/progression/progression_crafting_locked_up.dds", "/esoui/art/progression/remorph_up.dds",
    "/esoui/art/progression/removepoints_up.dds", "/esoui/art/progression/skillstyling_default_up.dds",
    "/esoui/art/progression/train_up.dds", "/esoui/art/progression/untrain_up.dds",
    "/esoui/art/repair/inventory_tabicon_repair_up.dds", "/esoui/art/skillsadvisor/advisor_tabicon_settings_up.dds",
    "/esoui/art/skillsadvisor/advisor_tabicon_tutorial_up.dds", "/esoui/art/tamrieltomes/timedactivitycategory_seasonal_up.dds",
    "/esoui/art/tamrieltomes/timedactivitycategory_weekly_up.dds", "/esoui/art/tamrieltomes/view_tomes_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_necklace_up.dds", "/esoui/art/tradinghouse/tradinghouse_apparel_accessories_ring_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_apparel_chest_up.dds", "/esoui/art/tradinghouse/tradinghouse_apparel_feet_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_apparel_hands_up.dds", "/esoui/art/tradinghouse/tradinghouse_apparel_head_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_apparel_legs_up.dds", "/esoui/art/tradinghouse/tradinghouse_apparel_shoulders_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_apparel_waist_up.dds", "/esoui/art/tradinghouse/tradinghouse_browse_tabicon_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_consumable_ability_up.dds", "/esoui/art/tradinghouse/tradinghouse_glyphs_trio_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_holiday_writ_up.dds", "/esoui/art/tradinghouse/tradinghouse_listings_tabicon_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_master_writ_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_mats_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_rawmats_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_blacksmithing_temper_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_enchanting_aspect_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_enchanting_essence_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_enchanting_potency_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_mats_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_plating_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_rawmats_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_jewelrymaking_rawplating_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_provisioning_drink_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_provisioning_food_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_provisioning_rare_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_style_rawmats_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_mats_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_rawmats_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_tailoring_tannin_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_mats_up.dds", "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_rawmats_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_materials_woodworking_resin_up.dds", "/esoui/art/tradinghouse/tradinghouse_potions_poisonsolvent_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_potions_potionsolvent_up.dds", "/esoui/art/tradinghouse/tradinghouse_racial_style_motif_book_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_racial_style_motif_chapter_up.dds", "/esoui/art/tradinghouse/tradinghouse_sell_tabicon_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_trophy_recipe_fragment_up.dds", "/esoui/art/tradinghouse/tradinghouse_trophy_runebox_fragment_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_trophy_treasure_map_up.dds", "/esoui/art/tradinghouse/tradinghouse_weapons_1h_axe_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_weapons_1h_dagger_up.dds", "/esoui/art/tradinghouse/tradinghouse_weapons_1h_mace_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_weapons_1h_sword_up.dds", "/esoui/art/tradinghouse/tradinghouse_weapons_2h_axe_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_weapons_2h_mace_up.dds", "/esoui/art/tradinghouse/tradinghouse_weapons_2h_sword_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_weapons_staff_flame_up.dds", "/esoui/art/tradinghouse/tradinghouse_weapons_staff_frost_up.dds",
    "/esoui/art/tradinghouse/tradinghouse_weapons_staff_lightning_up.dds", "/esoui/art/treeicons/achievements_indexicon_summary_up.dds",
    "/esoui/art/treeicons/antiquities_indexicon_scryable_up.dds", "/esoui/art/treeicons/store_indexicon_chapters_up.dds",
    "/esoui/art/treeicons/store_indexicon_promotion_up.dds", "/esoui/art/treeicons/tutorial_idexicon_groups_up.dds",
    "/esoui/art/tribute/tribute_tabicon_tribute_up.dds", "/esoui/art/vendor/tabicon_mounts_up.dds",
    "/esoui/art/vendor/vendor_tabicon_buy_up.dds", "/esoui/art/vendor/vendor_tabicon_buyback_up.dds",
    "/esoui/art/vendor/vendor_tabicon_fence_up.dds", "/esoui/art/vendor/vendor_tabicon_repair_up.dds",
    "/esoui/art/vendor/vendor_tabicon_sell_up.dds", "/esoui/art/vendor/vendor_tabicon_sellvengeance_up.dds",
    "/esoui/art/worldmap/map_ava_tabicon_foodfarm_up.dds", "/esoui/art/worldmap/map_ava_tabicon_keepsummary_up.dds",
    "/esoui/art/worldmap/map_ava_tabicon_oremine_up.dds", "/esoui/art/worldmap/map_ava_tabicon_resourcedefense_up.dds",
    "/esoui/art/worldmap/map_ava_tabicon_resourceproduction_up.dds", "/esoui/art/worldmap/map_ava_tabicon_woodmill_up.dds",
    "/esoui/art/worldmap/map_indexicon_filters_up.dds", "/esoui/art/worldmap/map_indexicon_housing_up.dds",
    "/esoui/art/worldmap/map_indexicon_key_up.dds", "/esoui/art/worldmap/map_indexicon_locations_up.dds",
    "/esoui/art/worldmap/map_indexicon_quests_up.dds", "/esoui/art/writadvisor/advisor_tabicon_equip_up.dds",
    "/esoui/art/writadvisor/advisor_tabicon_quests_up.dds",
}

local lower = zo_strlower or string.lower

local function FileName(path)
    return (path:match("([^/]+)%.dds$") or path):gsub("_up$", ""):gsub("_", " ")
end

local function ToEntries(paths)
    local result = {}
    for _, path in ipairs(paths) do
        result[#result + 1] = { icon = path, name = FileName(path), key = lower(path) }
    end
    return result
end

-- Значки мест: значки всех точек перемещения + значки легенды карты
function Icons:GetPlaces()
    if not self.places then
        local seen, paths = {}, {}
        for _, node in ipairs(QTM.Data:GetNodes()) do
            local icon = node.icon
            if icon and icon ~= "" and not seen[lower(icon)] then
                seen[lower(icon)] = true
                paths[#paths + 1] = icon
            end
        end
        table.sort(paths)
        self.places = ToEntries(paths)
    end
    return self.places
end

function Icons:GetEmblems()
    if not self.emblems then self.emblems = ToEntries(Icons.EMBLEMS) end
    return self.emblems
end

function Icons:GetGlyphs()
    if not self.glyphs then self.glyphs = ToEntries(Icons.GLYPHS) end
    return self.glyphs
end

-- Значки коллекций: ездовые животные, питомцы, памятные вещи, дома, костюмы...
local COLLECTIBLE_TYPES = {
    "COLLECTIBLE_CATEGORY_TYPE_MOUNT", "COLLECTIBLE_CATEGORY_TYPE_VANITY_PET",
    "COLLECTIBLE_CATEGORY_TYPE_MEMENTO", "COLLECTIBLE_CATEGORY_TYPE_HOUSE",
    "COLLECTIBLE_CATEGORY_TYPE_ASSISTANT", "COLLECTIBLE_CATEGORY_TYPE_COMPANION",
    "COLLECTIBLE_CATEGORY_TYPE_PERSONALITY", "COLLECTIBLE_CATEGORY_TYPE_COSTUME",
    "COLLECTIBLE_CATEGORY_TYPE_HAT", "COLLECTIBLE_CATEGORY_TYPE_POLYMORPH",
    "COLLECTIBLE_CATEGORY_TYPE_SKIN", "COLLECTIBLE_CATEGORY_TYPE_EMOTE",
    "COLLECTIBLE_CATEGORY_TYPE_TRIBUTE_PATRON", "COLLECTIBLE_CATEGORY_TYPE_ABILITY_FX_OVERRIDE",
    "COLLECTIBLE_CATEGORY_TYPE_PLAYER_FX_OVERRIDE", "COLLECTIBLE_CATEGORY_TYPE_FURNITURE",
    "COLLECTIBLE_CATEGORY_TYPE_DLC", "COLLECTIBLE_CATEGORY_TYPE_CHAPTER",
}

function Icons:GetCollectibles()
    if not self.collectibles then
        local seen, result = {}, {}
        for _, typeName in ipairs(COLLECTIBLE_TYPES) do
            local categoryType = _G[typeName]
            if categoryType then
                for index = 1, GetTotalCollectiblesByCategoryType(categoryType) do
                    local collectibleId = GetCollectibleIdFromType(categoryType, index)
                    if collectibleId and collectibleId ~= 0 then
                        local name, _, icon = GetCollectibleInfo(collectibleId)
                        if icon and icon ~= "" and not seen[lower(icon)] then
                            seen[lower(icon)] = true
                            name = zo_strformat("<<1>>", name or "")
                            result[#result + 1] = { icon = icon, name = name, key = lower(name .. " " .. icon) }
                        end
                    end
                end
            end
        end
        table.sort(result, function(a, b) return a.name < b.name end)
        self.collectibles = result
    end
    return self.collectibles
end

function Icons:GetTab(tab)
    if tab == Icons.TAB_PLACES then return self:GetPlaces() end
    if tab == Icons.TAB_EMBLEMS then return self:GetEmblems() end
    if tab == Icons.TAB_GLYPHS then return self:GetGlyphs() end
    return self:GetCollectibles()
end

local TAB_KEYS = {
    [Icons.TAB_PLACES]       = "ICONS_TAB_PLACES",
    [Icons.TAB_EMBLEMS]      = "ICONS_TAB_EMBLEMS",
    [Icons.TAB_GLYPHS]       = "ICONS_TAB_GLYPHS",
    [Icons.TAB_COLLECTIBLES] = "ICONS_TAB_COLLECTIBLES",
}
Icons.TAB_NAMES = setmetatable({}, {
    __index = function(_, tab) return TAB_KEYS[tab] and L[TAB_KEYS[tab]] or "" end,
})
