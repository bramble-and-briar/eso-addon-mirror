--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local function RegisterString(id, text)
	if _G[id] then
		SafeAddString(_G[id], text, 1)
	else
		ZO_CreateStringId(id, text)
		SafeAddVersion(_G[id], 1)
	end
end

local strings = {

	BLUE = "Blue",
	CHAT_MESSAGES = "Chat Logs",
	CHAT_MESSAGES_OFF = "Chat messages off. Type /oneaphatime chat to turn them back on.",
	CHAT_MESSAGES_ON = "Chat messages on. Type /oneaphatime chat to turn them off.",
	COLLECTIBLE_FRAGMENTS = "Collectible fragments",
	CONTAINERS = "Containers",
	COULD_NOT_BE_USED = "could not be used",
	CRAFTING_MOTIFS = "Crafting motifs",
	FOOD_AND_DRINK_RECIPES = "Food and drink recipes",
	FURNISHING_IN_BACKPACK = "%s is in your backpack; the rest stays in the %s.",
	FURNISHING_PLANS = "Furnishing plans",
	FURNISHING_VAULT = "Furnishing Vault",
	GET_ALL = "Get All (%s)",
	GET_ALL_NO_KEY_YET_SET = "Get All (no key yet, set one under Controls)",
	GET_ALL_QUALITY = "Get All: quality",
	GET_ALL_TYPES = "Get All: types",
	GET_ONE = "Get One",
	GET_ONE_FURNISHING = "Get One Furnishing",
	GOLD = "Gold",
	GREEN = "Green",
	GUILD_BANK = "guild bank",
	HOUSE_STORAGE = "house storage",
	HOW_IT_WORKS = "At any bank, house storage or the Furnishing Vault, Get One takes one from a stack and %s takes one of everything the filters allow. What you take is learned or opened once you close the storage. %s turns this off and on.",
	HOW_IT_WORKS_TITLE = "How it works",
	IS_ALREADY_KNOWN = "is already known",
	IS_ALREADY_KNOWN_SO_IT_STAYS = "%s is already known, so it stays where it is.",
	IS_IN_YOUR_BACKPACK_AND_GETS = "%s is in your backpack and gets used when you close the %s.",
	IS_NOT_INSTALLED_SO_THERE_IS = "%s is not installed, so there is no settings panel; Get All takes white and green items of every type.",
	NEVER_REACHED_YOUR_BACKPACK = "%s never reached your backpack.",
	NOTHING_HERE_YOU_CAN_STILL_LEARN = "Nothing here you can still learn or open that the Get All filter allows.",
	NOT_DURING_COMBAT = "Not during combat.",
	OFF_WITHDRAW_TAKES_THE_WHOLE_STACK = "Off. Withdraw takes the whole stack again and Get All does nothing.",
	OVERRIDE_WITHDRAW_BUTTON = "Override Withdraw Button",
	PURPLE = "Purple",
	PUTS_EVERY_SETTING_ON_THIS_PANEL = "Puts every setting on this panel back to its default.",
	RECIPE_FRAGMENTS = "Recipe fragments",
	RESET_TO_DEFAULTS = "|cFF3333RESET TO DEFAULTS|r",
	RUNEBOXES = "Runeboxes",
	RUNEBOX_FRAGMENTS = "Runebox fragments",
	SCRIBING_ITEMS = "Scribing items",
	SETTINGS_ARE_BACK_TO_THEIR_DEFAULTS = "Settings are back to their defaults.",
	SO_IT_GOES_BACK_NEXT_TIME = "%s %s, so it goes back next time you open that %s.",
	STYLE_PAGES = "Style pages",
	TAKING_ONE_EACH_OF_ITEM_ONE = "Taking one each of %d item%s, one at a time.",
	THE_CLOSED_WITH_STILL_TO_TAKE = "The %s closed with %d still to take.",
	THE_GAME_WOULD_NOT_MOVE_IT = "The game would not move it right now.",
	THE_GUILD_BANK_DID_NOT_HAND = "The guild bank did not hand over %s.",
	THE_REST_OF_THAT_STACK_IS = "The rest of that stack is in your backpack; put it back in the guild bank by hand.",
	TOGGLE_NO_KEY_YET_SET = "The Turn On or Off key (not set yet, see Controls)",
	TOGGLE_ON = "On. Get One on a stack of recipes, motifs, fragments, scripts, containers or furnishings takes one, and %s takes one of everything the settings allow. They are used once you close the bank, guild bank or house storage.",
	TOOK_THEY_GET_USED_WHEN_YOU = "Took %d. They get used when you close the %s.",
	TURN_OFF = "Turn One APH a Time Off",
	TURN_ON = "Turn One APH a Time On",
	WENT_BACK = "%s went back.",
	WHITE = "White",
	YOUR_BACKPACK_IS_TOO_FULL_TO = "Your backpack is too full to take more; %d left in storage.",
}

for key, text in pairs(strings) do
	RegisterString("SI_OAPH_" .. key, text)
end

RegisterString("SI_BINDING_NAME_OAPH_GET_ALL", "Get All")
RegisterString("SI_BINDING_NAME_OAPH_TOGGLE", "Turn One APH a Time On or Off")
