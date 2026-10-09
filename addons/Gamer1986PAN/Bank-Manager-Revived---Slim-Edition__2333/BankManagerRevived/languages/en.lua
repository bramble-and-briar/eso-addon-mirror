--[[
File : en.lua
Version : 4.5
Author : Ayantir
]]--

local lang = {

	--Option Translation
	
	BMR_AUTO_TRANSFERT							= "Automatic transfer when opening bank",
	BMR_AUTO_TRANSFERT_TOOLTIP					= "When opening bank, all moving operations will be performed",
	
	BMR_STACK_DETAILLED							= "Display detailled moves",
	BMR_STACK_DETAILLED_TOOLTIP				= "Display details of each item moved in chat",
	
	BMR_DISPLAY_SUMMARY							= "Display Summary",
	BMR_DISPLAY_SUMMARY_TOOLTIP				= "Display the summary of the number of moved items & currencies",
	
	BMR_STACK_DETAILLED_NOTMOVED				= "Display failed moves",
	BMR_STACK_DETAILLED_NOTMOVED_TOOLTIP	= "Display a message when BMR didn't succeeded to move an item due to free space missing in destination bag",
	
	BMR_DONT_MOVE_PROTECTED_ITEMS				= "Don't move protected items",
	BMR_DONT_MOVE_PROTECTED_ITEMS_TOOLTIP	= "Don't move items locked by ESO, ItemSaver or FCO ItemSaver",
	
	BMR_DONT_MOVE_MOVED_ITEMS					= "Don't move items moved by another source",
	BMR_DONT_MOVE_MOVED_ITEMS_TOOLTIP		= "Don't move items previously moved by another addon or by yourself while interacting at bank",
	
	BMR_WAIT_AT_STARTUP							= "Time before working when opening banks",
	BMR_WAIT_AT_STARTUP_TOOLTIP				= "Lower the value if you don't want to wait. A low value can bug BMR if your computer is a bit slow especially at Guild Bank",
	
	BMR_NO_OVERFILL								= "Keep free slots in my bags",
	BMR_NO_OVERFILL_TOOLTIP						= "If set, BMR will try to keep this count of free slots in your bag and won't move additional items if the limit is reached",
	
	BMR_DELAY_BETWEEN_MOVES						= "Delay between moves",
	BMR_DELAY_BETWEEN_MOVES_TOOLTIP			= "Add a delay between each moves to avoid potential crashes and/or game kicks",
	
	BMR_ONLY_IF_NOT_FULL_STACK					= "Only if not full stack",
	BMR_ONLY_IF_NOT_FULL_STACK_TOOLTIP		= "Move items only if the bag which will receive don't have already a full stack",
	
	BMR_MAX_STACK									= "Max Stacks",
	BMR_MAX_STACK_TOOLTIP						= "Max Stacks of items to move to the desired bag",
	
	BMR_GUILD_LIST									= "Associated Guild Bank",
	BMR_GUILD_LIST_TOOLTIP						= "Name of the Guild Bank linked to the rules defined under. BMR will push items into this guild bank if conditions meet your personnal choices",
	
	BMR_GLOBAL_ADDON_PROFILE						= "Global Addon Profile (auto reload when selected)",
	BMR_GLOBAL_ADDON_PROFILE_TOOLTIP				= "Select the global BMR addon profile. The UI will reload after changing it. Default: <<1>>",
	BMR_PROFILE_COUNT							= "Number of profiles",
	BMR_PROFILE_COUNT_TOOLTIP					= "Controls how many BMR profiles are available. Profiles above this number are kept but hidden until the value is increased again.",

	-- ScriptTracker
	BMR_SCRIPTTRACKER							= "ScriptTracker / Scriptures",
	BMR_SCRIPTTRACKER_DESC						= "Automatically deposit scripts already known by the current character and withdraw scripts the character does not know yet. BMR performs the actual item transfers.",
	BMR_SCRIPTTRACKER_ENABLE						= "Enable automatic script management",
	BMR_SCRIPTTRACKER_ENABLE_TOOLTIP				= "Uses ScriptTracker's current-character knowledge when the bank is opened.",
	BMR_SCRIPTTRACKER_DEPOSIT_KNOWN				= "Deposit known scripts",
	BMR_SCRIPTTRACKER_WITHDRAW_UNKNOWN			= "Withdraw unknown scripts",
	BMR_SCRIPTTRACKER_ONE_ONLY					= "Withdraw only one copy per unknown script",
	BMR_SCRIPTTRACKER_ONE_ONLY_TOOLTIP			= "If enabled, BMR takes at most one copy of each unknown script from the bank. A script already in the inventory is never withdrawn again.",
	BMR_SCRIPTTRACKER_DEBUG						= "Enable ScriptTracker debug output",
	BMR_SCRIPTTRACKER_DEBUG_TOOLTIP				= "Writes detailed ScriptTracker/BMR transfer diagnostics to the chat. Disabled by default.",

	-- Profiles
	BMR_PROFILES									= "Profiles",
	BMR_PROFILE_LIST								= "Profile actually selected",
	BMR_PROFILE_LIST_TOOLTIP					= "For each character you can set 9 different profiles with specific rules",
	BMR_PROFILE_NAME								= "Name of the profile",
	BMR_PROFILE_NAME_TOOLTIP					= "Name of the profile actually selected",
	BMR_PROFILE_RESET								= "Reset profile",
	BMR_PROFILE_RESET_TOOLTIP					= "Reset this profile to default values",
	
	BMR_PROFILE										= "Profile <<1>>",
	
	-- Currencies
	BMR_CURRENCY_PUSH								= "Keep currency",
	BMR_CURRENCY_PUSH_TOOLTIP					= "Keep this amount in your inventory\n\nIf you set the value for 'Fill-up to' this one will be used as minimum value for the option here",
	
	BMR_CURRENCY_PULL								= "Fill-up to",
	BMR_CURRENCY_PULL_TOOLTIP					= "Fill-up from the bank to your inventory with this value. Leave 0 to disable the option",
	
	BMR_CURRENCY_NOTHING							= "Don't keep any <<1>>",
	BMR_CURRENCY_NOTHING_TOOLTIP				= "When \"Keep Currency\" is set to 0, you'll need to confirm by setting this value to push all your <<1>> in bank",
	
	BMR_CURRENCY_KEEP_IN_BANK					= "Keep in Bank instead of Bag",
	BMR_CURRENCY_KEEP_IN_BANK_TOOLTIP		= "Keep the desired amount in Bank instead of Bag and fill-up in bank if the Fill-Up option is defined",
	
	-- GetSkillLineInfo cannot be used. If you start game in FR Blacksmithing will be 5, even if you do a SetCVar, If you start game in EN, Blacksmithing will be 2. even if in the both languages they're at the 2nd position.
	BMR_TRADESKILL_ALCHEMY						= "Alchemy",
	BMR_TRADESKILL_CLOTHIER						= "Clothing",
	BMR_TRADESKILL_PROVISIONING					= "Provisioning",
	BMR_TRADESKILL_ENCHANTING					= "Enchanting",
	BMR_TRADESKILL_BLACKSMITHING				= "Blacksmithing",
	BMR_TRADESKILL_WOODWORKING					= "Woodworking",
	BMR_TRADESKILL_JEWELRYCRAFTING				= "Jewelry Crafting",
	
	-- Trophies are hardcoded because there is nothing to label them
	BMR_TROPHY_TREASURE_MAP						= "Treasure Maps",
	BMR_TROPHY_SURVEY_MAP						= "Survey Maps",
	BMR_TROPHY_MOTIF_FRAGMENT					= "Style Motif Fragments",
	BMR_TROPHY_RECIPE_FRAGMENT					= "Recipe Fragments",
	BMR_TROPHY_IMPERIALCITY_PVE				= "Imperial City Trophies",
	BMR_TROPHY_QUEST_REWARD						= "Quest Rewards Trophies",
	
	-- Writ quests
	BMR_WRIT_QUESTS								= "Pull materials for writs",
	BMR_WRIT_QUESTS_TOOLTIP						= "Pull desired materials in bag for doing daily writs",
	
	-- Bindings
	SI_BINDING_NAME_BMR_PROFILE1				= "Run Profile 1",
	SI_BINDING_NAME_BMR_PROFILE2				= "Run Profile 2",
	SI_BINDING_NAME_BMR_PROFILE3				= "Run Profile 3",
	SI_BINDING_NAME_BMR_PROFILE4				= "Run Profile 4",
	SI_BINDING_NAME_BMR_PROFILE5				= "Run Profile 5",
	SI_BINDING_NAME_BMR_PROFILE6				= "Run Profile 6",
	SI_BINDING_NAME_BMR_PROFILE7				= "Run Profile 7",
	SI_BINDING_NAME_BMR_PROFILE8				= "Run Profile 8",
	SI_BINDING_NAME_BMR_PROFILE9				= "Run Profile 9",
	
	-- Dropwdons
	BMR_ACTION_PUSH								= "Push to Bank",
	BMR_ACTION_PULL								= "Pull from Bank",
	BMR_ACTION_NOTSET								= "-",
	BMR_ACTION_PUSH_GBANK						= "Push to Guild Bank",
	BMR_ACTION_PUSH_BOTH							= "Push to both Banks",
	
	-- Chat notifications
	BMR_ACTION_ITEMS_MOVED						= "BMR has moved <<3>>x |t16:16:<<2>>|t<<1>> <<4>>",
	BMR_ACTION_ITEMS_NOT_MOVED					= "BMR didn't moved <<3>>x |t16:16:<<2>>|t<<1>> <<4>>",
	BMR_ACTION_CURRENCY_SUMMARY				= "BMR has moved <<1>> <<2>>",
	BMR_ACTION_CURRENCY_GSUMMARY				= "<<1>> <<2>>",
	
	BMR_ACTION_HAS_MOVED							= "BMR has moved ",
	BMR_ACTION_CURRENCY_MOVED_TO2				= "to the bank",
	BMR_ACTION_CURRENCY_MOVED_TO3				= "to the bag",
	
	BMR_ACTION_ITEMS_MOVED_TO1					= "to the bag",
	BMR_ACTION_ITEMS_MOVED_TO2					= "to the bank",
	BMR_ACTION_ITEMS_MOVED_TO6					= "to the bank",
	BMR_ACTION_ITEMS_MOVED_TO3					= "to the guild bank <<5>>",
	
	BMR_ACTION_ITEMS_SUMMARY					= "BMR has moved <<1>>x different items (<<2>> items) ",
	BMR_RARE_INGREDIENTS							= "<<1>>, <<2>> & <<3>>",
	
	-- Import
	BMR_IMPORT										= "Import BMR settings from",
	BMR_IMPORT_DESC								= "Select from which character BMR should import its settings. Please note that settings remains character-based and are not synched between characters",
	BMR_IMPORTED									= "BMR settings have been imported from character <<1>>",
	
	BMR_ZOS_LIMITATIONS							= "Due to game restrictions, BMR processed only 98 items. Please wait 10 seconds, and interact again with npc.",
	
	BMR_RULE_WRITER								= "Rule Writer",
	BMR_RULE_WRITER_DESC							= "Use the editbox under to add a rule, each rule must contain one or more criterions separated by the symbol +, then the action is determined by the symbol = and the action to do.\n\nFor more details about the rule writer, please click on Website link at top of the option panel for a complete documentation",
	
	BMR_RULE_WRITER_ADDNEWRULE					= "Type the rule you may want to create",
	BMR_RULE_WRITER_ADDNEWRULE_TOOLTIP		= "Use this editbox under to add a rule, please note that the rule is evaluated when the focus of this control is lost. If the text is stripped, that means you have an error. If the rule is well writen, a recap message will appear on screen.",
	
	BMR_RULE_WRITER_RUNAFTER					= "Run user rules after BMR ones",
	BMR_RULE_WRITER_RUNAFTER					= "Your rules will be run after BMR ones",
	
}

--Create the string values, so other languages can add new versions
for stringId, stringValue in pairs(lang) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end