local strings = {
	BANKIR_MENU_PROFILES = "Profiles",
	BANKIR_MENU_PROFILE_SELECT = "Select profile",
	BANKIR_MENU_PROFILE_SELECT_DESC = "Select settings profile for your current character",
	BANKIR_MENU_PROFILE_EDIT_NAME = "Edit profile name",
	BANKIR_MENU_PROFILE_NEW = "New profile",
	BANKIR_MENU_PROFILE_COPY = "Copy profile",
	BANKIR_MENU_PROFILE_COPY_DESC = "Will create a new profile that is a copy of the current profile",
	BANKIR_MENU_PROFILE_DELETE = "Delete profile",
	BANKIR_MENU_PROFILE_DELETE_WARNING = "This will completely remove the currently selected profile!",

	BANKIR_MENU_MOVE_LOCKED_ITEMS = "Move locked items",
	BANKIR_MENU_MOVE_LOCKED_ITEMS_DESC = "Allow moving items locked by the player",
	BANKIR_MENU_SHOW_MOVE_REASON = "Show move reason",
	BANKIR_MENU_SHOW_MOVE_REASON_DESC = "Moved item info in chat will have an additional tag with rule name based on which the item has been moved by Bankir",
	BANKIR_MENU_SHOW_DEPOSIT_NOT_ALLOWED_MESSAGE = "Show fail messages",
	BANKIR_MENU_SHOW_DEPOSIT_NOT_ALLOWED_MESSAGE_DESC = "Print in chat if item transaction failed",
	BANKIR_MENU_BANK_SLIDERS_MAX_VALUE = "Bank sliders max",
	BANKIR_MENU_BANK_SLIDERS_MAX_VALUE_DESC = "Maximum value for '<<1>>' and '<<2>>' sliders in items rules",
	BANKIR_MENU_CURRENCY_SLIDERS_MAX_VALUE = "Currency sliders max",
	BANKIR_MENU_CURRENCY_SLIDERS_MAX_VALUE_DESC = "Maximum value for sliders in currency rules",

	BANKIR_MENU_CURRENT_PROFILE_NAME = "Current profile: ",
	BANKIR_MENU_CURRENT_PROFILE_NAME_DESC = "To change current profile go to settings menu",
	BANKIR_MENU_BANK_SELECT = "Bank bag to set up",
	BANKIR_MENU_BANK_SELECT_DESC = "Select which bank bag to set up.\nThe list contains bank, all unlocked house coffers, and all your guild banks.\nThe settings below will apply to the bank bag selected here",

	BANKIR_MENU_CURRENCY_DEPOSIT = "Deposit <<1>> <<2>>",
	BANKIR_MENU_CURRENCY_DEPOSIT_DESC = "Deposit the currency exceeding the slider value into the bank",
	BANKIR_MENU_CURRENCY_WITHDRAW = "Withdraw <<1>> <<2>>",
	BANKIR_MENU_CURRENCY_WITHDRAW_DESC = "Withdraw currency from the bank if character has less than the slider value",
	BANKIR_MENU_CURRENCY_AMOUNT = "Amount to keep on character",
	BANKIR_MENU_CURRENCY_AMOUNT_DESC = "Select how much currency to keep on character",

	BANKIR_MENU_PUSH_DESC = "Maximum number of full stacks needed in the bank bag.\nIf bank has less stacks, Bankir will try to fulfill them from the inventory",
	BANKIR_MENU_PULL_DESC = "Minimal amount to keep at character's inventory.\nIf character has less, Bankir will try to get them from bank, when available",
	BANKIR_MENU_PULL_IN_STACKS = "<<1>> full stacks",
	BANKIR_MENU_PULL_IN_STACKS_DESC = "If enabled - the value in '<<1>>' is amount of full stacks.\nIf disabled - amount of items.\nFor non-stackable items (e.g., armor and weapon) this setting doesn't matter.",
	BANKIR_MENU_QUALITY_SELECT = "Quality",
	BANKIR_MENU_QUALITY_SELECT_DESC = "The rule will only apply to items with quality of selected levels",

	BANKIR_MENU_OTHER_CHARACTERS = " on other characters",
	
	BANKIR_CHAT_REQUIRED_FOR_QUESTS = "<<1>> x<<2>> required for quests",
	BANKIR_CHAT_NO_FREE_SPACE = "|cFF0000Failed.|r No free space left in <<1>> for <<2>>.",
	BANKIR_CHAT_ALREADY_HAVE_UNIQUE_ITEM = "|cFF0000Failed.|r You can only have one <<1>> in a storage, and you already have one in <<2>>.",
	
	BANKIR_MENU_INTEGRATIONS = "Integrations",
	BANKIR_MENU_INTEGRATIONS_LCK_DESC = "If LibCharacterKnowledge addon is enabled, Bankir will have special rules for equipment that can be trait-researched on your other characters.\n\nHere is a list of your other characters on this server.\n\nIf you have set a rule to deposit items that can be researched on other characters, Bankir will move such items only for the characters enabled in this list. Not enabled characters will be ignored.",
	
	BANKIR_DEBUG_UNKNOWN = "Bankir doesn't know this thing",
}

-- Create the string values, so other languages can add new versions
for stringId, stringValue in pairs(strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end