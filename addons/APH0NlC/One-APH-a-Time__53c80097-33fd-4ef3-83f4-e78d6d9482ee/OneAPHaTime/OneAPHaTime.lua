--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local ADDON_NAME = "OneAPHaTime"

local function L(key, ...)
	local id = _G["SI_OAPH_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

local STEP_NAMESPACE = ADDON_NAME .. "Step"
local TIMEOUT_NAMESPACE = ADDON_NAME .. "Timeout"
local GAP_NAMESPACE = ADDON_NAME .. "Gap"
local KEYBIND_LAYER = "One APH a Time"
local GET_ALL_ACTION = "OAPH_GET_ALL"
local TOGGLE_ACTION = "OAPH_TOGGLE"
local GAMEPAD_GET_ALL_KEYBIND = "UI_SHORTCUT_QUINARY"
local PANEL_ID = "OAPHOptions"
local RESET_LABEL = L("RESET_TO_DEFAULTS")
local STEP_TIMEOUT_MS = 3000
local BANK_GAP_MS = 250
local GUILD_GAP_MS = 1000
local GUILD_RETRIES = 3
local GUILD_FREE_SLOTS = 2

local QUALITIES = {
	{ key = "white", label = L("WHITE"), quality = ITEM_DISPLAY_QUALITY_NORMAL },
	{ key = "green", label = L("GREEN"), quality = ITEM_DISPLAY_QUALITY_MAGIC },
	{ key = "blue", label = L("BLUE"), quality = ITEM_DISPLAY_QUALITY_ARCANE },
	{ key = "purple", label = L("PURPLE"), quality = ITEM_DISPLAY_QUALITY_ARTIFACT },
	{ key = "gold", label = L("GOLD"), quality = ITEM_DISPLAY_QUALITY_LEGENDARY },
}

local TYPES = {
	{ key = "recipes", label = L("FOOD_AND_DRINK_RECIPES") },
	{ key = "furnishing", label = L("FURNISHING_PLANS") },
	{ key = "motifs", label = L("CRAFTING_MOTIFS") },
	{ key = "style_pages", label = L("STYLE_PAGES") },
	{ key = "runeboxes", label = L("RUNEBOXES") },
	{ key = "collectible_fragments", label = L("COLLECTIBLE_FRAGMENTS") },
	{ key = "runebox_fragments", label = L("RUNEBOX_FRAGMENTS") },
	{ key = "recipe_fragments", label = L("RECIPE_FRAGMENTS") },
	{ key = "containers", label = L("CONTAINERS") },
	{ key = "scribing", label = L("SCRIBING_ITEMS") },
}

local function FilterDefaults()
	local qualities, types = {}, {}
	for _, q in ipairs(QUALITIES) do qualities[q.key] = q.key == "white" or q.key == "green" end
	for _, t in ipairs(TYPES) do types[t.key] = true end
	return { qualities = qualities, types = types }
end

local DEFAULTS = { enabled = true, furnishings = true, chat_messages = false, returns = {}, get_all = FilterDefaults(), warned_no_settings = false }
local SETTING_KEYS = { "enabled", "furnishings", "get_all" }

local QUALITY_KEY = {}
for _, q in ipairs(QUALITIES) do QUALITY_KEY[q.quality] = q.key end

local CONTAINER_TYPES = {
	[ITEMTYPE_CONTAINER] = true,
	[ITEMTYPE_CONTAINER_CURRENCY] = true,
	[ITEMTYPE_CONTAINER_STACKABLE] = true,
}

local TROPHY_CATEGORIES = {
	[SPECIALIZED_ITEMTYPE_TROPHY_COLLECTIBLE_FRAGMENT] = "collectible_fragments",
	[SPECIALIZED_ITEMTYPE_TROPHY_RUNEBOX_FRAGMENT] = "runebox_fragments",
	[SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT] = "recipe_fragments",
}

local STYLE_PAGES = {
	[SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE] = true,
	[SPECIALIZED_ITEMTYPE_COLLECTIBLE_STYLE_PAGE] = true,
}

local FOOD_RECIPES = {
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_FOOD] = true,
	[SPECIALIZED_ITEMTYPE_RECIPE_PROVISIONING_STANDARD_DRINK] = true,
}

local function CategoryOf(bag, slot)
	local itemType, specialized = GetItemType(bag, slot)
	if itemType == ITEMTYPE_FURNISHING then return "furnishings" end
	if itemType == ITEMTYPE_RECIPE then
		return FOOD_RECIPES[specialized] and "recipes" or "furnishing"
	end
	if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then return "motifs" end
	if itemType == ITEMTYPE_CRAFTED_ABILITY or itemType == ITEMTYPE_CRAFTED_ABILITY_SCRIPT then return "scribing" end
	if itemType == ITEMTYPE_TROPHY then return TROPHY_CATEGORIES[specialized] end
	if STYLE_PAGES[specialized] then return "style_pages" end
	if CONTAINER_TYPES[itemType] then
		local collectibleId = GetItemLinkContainerCollectibleId(GetItemLink(bag, slot))
		if collectibleId and collectibleId ~= 0 then return "runeboxes" end
		return "containers"
	end
	return nil
end


local saved
local job
local batch
local queue = {}
local held = {}
local using = false
local used = { Learned = {}, Opened = {}, Used = {} }
local open_storage
local InstallPrimaryOverride
local UninstallPrimaryOverride

local function PassesFilter(bag, slot)
	local category = CategoryOf(bag, slot)
	if not category or not saved.get_all.types[category] then return false end
	local quality = QUALITY_KEY[GetItemDisplayQuality(bag, slot)]
	return quality ~= nil and saved.get_all.qualities[quality] == true
end

local function Print(text, always)
	if not always and saved and saved.chat_messages == false then return false end
	d("|c9CD04C[One APH a Time]|r " .. text)
	return true
end

local function IsAlive()
	return not IsUnitDead("player")
end

local function IsStorageBag(bag)
	return bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK or bag == BAG_GUILDBANK or IsHouseBankBag(bag) or IsFurnitureVault(bag)
end

local function GetAllKeybind()
	if IsInGamepadPreferredMode() then return GAMEPAD_GET_ALL_KEYBIND end
	return GET_ALL_ACTION
end

local function KeyFor(action)
	return ZO_Keybindings_GetHighestPriorityBindingStringFromAction(action,
		KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, IsInGamepadPreferredMode())
end

local function GetAllPhrase()
	local key = KeyFor(GetAllKeybind())
	if key then return string.format(L("GET_ALL"), key) end
	return L("GET_ALL_NO_KEY_YET_SET")
end

local function TogglePhrase()
	return KeyFor(TOGGLE_ACTION) or L("TOGGLE_NO_KEY_YET_SET")
end

local function StorageName(bag)
	if bag == BAG_GUILDBANK then return L("GUILD_BANK") end
	if bag and IsHouseBankBag(bag) then return L("HOUSE_STORAGE") end
	if bag and IsFurnitureVault(bag) then return L("FURNISHING_VAULT") end
	return "bank"
end

local function IsAnyBankOpen()
	return IsBankOpen() or IsGuildBankOpen()
end

local function AlreadyKnown(link, itemType)
	if itemType == ITEMTYPE_RECIPE then return IsItemLinkRecipeKnown(link) end
	if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then return IsItemLinkBookKnown(link) end

	local useType = GetItemLinkItemUseType(link)
	local reference = GetItemLinkItemUseReferenceId(link)
	if useType == ITEM_USE_TYPE_CRAFTED_ABILITY then return IsCraftedAbilityUnlocked(reference) end
	if useType == ITEM_USE_TYPE_CRAFTED_ABILITY_SCRIPT then return IsCraftedAbilityScriptUnlocked(reference) end

	local collectibleId = GetItemLinkContainerCollectibleId(link)
	if collectibleId and collectibleId ~= 0 then return IsCollectibleUnlocked(collectibleId) end
	return false
end

local function CanUseGuildBank(guildId)
	return guildId
		and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_WITHDRAW)
		and DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_BANK_DEPOSIT)
end

local function FreeSlotsFor(bag)
	return bag == BAG_GUILDBANK and GUILD_FREE_SLOTS or 1
end

local function CanTakeFrom(bag, slot)
	if not saved or not saved.enabled then return false end
	if not bag or not slot or not IsStorageBag(bag) then return false end
	local category = CategoryOf(bag, slot)
	if not category then return false end
	if category == "furnishings" and not saved.furnishings then return false end
	if bag == BAG_GUILDBANK and not CanUseGuildBank(GetSelectedGuildBankId()) then return false end
	return GetNumBagFreeSlots(BAG_BACKPACK) >= FreeSlotsFor(bag)
end

local function CanGetOne(bag, slot)
	return CanTakeFrom(bag, slot) and GetSlotStackSize(bag, slot) > 1
end

local function FindInBackpack(itemId, single)
	local found
	for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
		if GetItemId(BAG_BACKPACK, slot) == itemId then
			if not single or GetSlotStackSize(BAG_BACKPACK, slot) == 1 then return slot end
			found = found or slot
		end
	end
	if single then return nil end
	return found
end

local function StackTarget(bag, itemId)
	for slot = 0, GetBagSize(bag) - 1 do
		if GetItemId(bag, slot) == itemId then
			local count, max = GetSlotStackSize(bag, slot)
			if count < max then return slot end
		end
	end
	return FindFirstEmptySlotInBag(bag)
end

local function StopWaiting()
	EVENT_MANAGER:UnregisterForEvent(STEP_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
	EVENT_MANAGER:UnregisterForEvent(STEP_NAMESPACE, EVENT_LOOT_UPDATED)
	EVENT_MANAGER:UnregisterForEvent(STEP_NAMESPACE, EVENT_LOOT_CLOSED)
	EVENT_MANAGER:UnregisterForEvent(STEP_NAMESPACE, EVENT_PLAYER_COMBAT_STATE)
	EVENT_MANAGER:UnregisterForEvent(STEP_NAMESPACE, EVENT_GUILD_BANK_TRANSFER_ERROR)
	EVENT_MANAGER:UnregisterForUpdate(TIMEOUT_NAMESPACE)
end

local function OnTimeout(fn)
	EVENT_MANAGER:UnregisterForUpdate(TIMEOUT_NAMESPACE)
	EVENT_MANAGER:RegisterForUpdate(TIMEOUT_NAMESPACE, STEP_TIMEOUT_MS, function()
		StopWaiting()
		fn()
	end)
end

local function After(ms, fn)
	EVENT_MANAGER:UnregisterForUpdate(GAP_NAMESPACE)
	EVENT_MANAGER:RegisterForUpdate(GAP_NAMESPACE, ms, function()
		EVENT_MANAGER:UnregisterForUpdate(GAP_NAMESPACE)
		fn()
	end)
end

local function WaitForBackpack(accept, done, timed_out)
	StopWaiting()
	EVENT_MANAGER:RegisterForEvent(STEP_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag, slot, _, _, _, change)
		if bag ~= BAG_BACKPACK or not accept(slot, change) then return end
		StopWaiting()
		done(slot, change)
	end)
	EVENT_MANAGER:AddFilterForEvent(STEP_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	OnTimeout(timed_out)
end

local function GuildStep(action, accept, done, failed, tries)
	tries = tries or 0
	WaitForBackpack(accept, done, failed)
	EVENT_MANAGER:RegisterForEvent(STEP_NAMESPACE, EVENT_GUILD_BANK_TRANSFER_ERROR, function(_, reason)
		StopWaiting()
		if reason == GUILD_BANK_TRANSFER_PENDING and tries < GUILD_RETRIES then
			After(GUILD_GAP_MS, function() GuildStep(action, accept, done, failed, tries + 1) end)
		else
			failed()
		end
	end)
	action()
end

local function Move(fromBag, fromSlot, toBag, toSlot, count)
	return CallSecureProtected("RequestMoveItem", fromBag, fromSlot, toBag, toSlot, count)
end

local function Arrived(target)
	return function(slot, change) return slot == target and change > 0 end
end

local function Left(target)
	return function(slot, change) return slot == target and change < 0 end
end

local function ClearQueue()
	local left = #queue
	for i = #queue, 1, -1 do queue[i] = nil end
	return left
end

local function Remember(entry, reason)
	saved.returns[#saved.returns + 1] = { bag = entry.bag, guildId = entry.guildId, itemId = entry.itemId }
	Print(string.format(L("SO_IT_GOES_BACK_NEXT_TIME"), entry.link, reason, StorageName(entry.bag)))
end

local StartNext, UseNext

local USE_VERBS = {
	recipes = "Learned", furnishing = "Learned", motifs = "Learned", scribing = "Learned",
	containers = "Opened", runeboxes = "Opened", style_pages = "Opened",
}

local function RecordUse(entry, verb)
	local list = used[verb]
	list[#list + 1] = entry.link
end

local function ReportUses()
	local parts = {}
	for _, verb in ipairs({ "Learned", "Opened", "Used" }) do
		local list = used[verb]
		if #list > 0 then parts[#parts + 1] = verb .. ": " .. table.concat(list, ", ") end
		used[verb] = {}
	end
	if #parts > 0 then Print(table.concat(parts, ". ") .. ".") end
end

local function UseHeld(entry, slot)
	local verb = USE_VERBS[CategoryOf(BAG_BACKPACK, slot)] or "Used"
	EVENT_MANAGER:RegisterForEvent(STEP_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag, changed, _, _, _, change)
		if bag ~= BAG_BACKPACK or changed ~= slot or change >= 0 then return end
		RecordUse(entry, verb)
		UseNext()
	end)
	EVENT_MANAGER:AddFilterForEvent(STEP_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	EVENT_MANAGER:RegisterForEvent(STEP_NAMESPACE, EVENT_LOOT_UPDATED, function()
		RecordUse(entry, "Opened")
		StopWaiting()
		EVENT_MANAGER:RegisterForEvent(STEP_NAMESPACE, EVENT_LOOT_CLOSED, function() UseNext() end)
	end)
	OnTimeout(function()
		Remember(entry, L("COULD_NOT_BE_USED"))
		UseNext()
	end)

	if not CallSecureProtected("UseItem", BAG_BACKPACK, slot) then
		StopWaiting()
		Remember(entry, L("COULD_NOT_BE_USED"))
		UseNext()
	end
end

function UseNext()
	StopWaiting()
	local entry = held[1]
	if IsAnyBankOpen() or not entry then
		using = false
		if not entry then
			ReportUses()
			if LibAPH and LibAPH.StepCleanup then LibAPH.StepCleanup(1) end
		end
		if queue[1] then StartNext() end
		return
	end
	using = true

	if IsUnitInCombat("player") then
		EVENT_MANAGER:RegisterForEvent(STEP_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
			if not inCombat then UseNext() end
		end)
		return
	end

	table.remove(held, 1)
	local slot = FindInBackpack(entry.itemId)
	if not slot then return UseNext() end
	if AlreadyKnown(entry.link, GetItemType(BAG_BACKPACK, slot)) then
		Remember(entry, L("IS_ALREADY_KNOWN"))
		return UseNext()
	end
	UseHeld(entry, slot)
end

local function Finish(text)
	StopWaiting()
	local was = job
	job = nil
	if text then Print(text) end

	if queue[1] then
		After(was and was.bag == BAG_GUILDBANK and GUILD_GAP_MS or BANK_GAP_MS, StartNext)
		return
	end
	if batch then
		if batch.taken > 0 then
			Print(string.format(L("TOOK_THEY_GET_USED_WHEN_YOU"), batch.taken, StorageName(batch.bag)))
		end
		batch = nil
	end
	if held[1] then UseNext() end
end

local function Hold(slot)
	if job.keep then
		return Finish(string.format(L("FURNISHING_IN_BACKPACK"), job.link, StorageName(job.bag)))
	end
	held[#held + 1] = { bag = job.bag, guildId = job.guildId, itemId = GetItemId(BAG_BACKPACK, slot), link = job.link }
	if batch then
		batch.taken = batch.taken + 1
		return Finish()
	end
	Finish(string.format(L("IS_IN_YOUR_BACKPACK_AND_GETS"), job.link, StorageName(job.bag)))
end

local function StartFromBank()
	local one = FindFirstEmptySlotInBag(BAG_BACKPACK)
	WaitForBackpack(Arrived(one), function() Hold(one) end, function()
		Finish(string.format(L("NEVER_REACHED_YOUR_BACKPACK"), job.link))
	end)
	if not Move(job.bag, job.slot, BAG_BACKPACK, one, 1) then
		Finish(L("THE_GAME_WOULD_NOT_MOVE_IT"))
	end
end

local function StartFromGuildBank()
	local function Lost(text) return function() Finish(text) end end
	local rest_lost = Lost(L("THE_REST_OF_THAT_STACK_IS"))

	local function Landed(_, change) return change > 0 end
	GuildStep(function() TransferFromGuildBank(job.slot) end, Landed, function(landing, count)
		if count == 1 then return Hold(landing) end

		local spare = FindFirstEmptySlotInBag(BAG_BACKPACK)
		local mine = GetSlotStackSize(BAG_BACKPACK, landing) - count
		if mine <= 0 then
			WaitForBackpack(Arrived(spare), function()
				GuildStep(function() TransferToGuildBank(BAG_BACKPACK, landing) end, Left(landing),
					function() Hold(spare) end, rest_lost)
			end, rest_lost)
			Move(BAG_BACKPACK, landing, BAG_BACKPACK, spare, 1)
		else
			WaitForBackpack(Arrived(spare), function()
				GuildStep(function() TransferToGuildBank(BAG_BACKPACK, spare) end, Left(spare),
					function() Hold(landing) end, rest_lost)
			end, rest_lost)
			Move(BAG_BACKPACK, landing, BAG_BACKPACK, spare, count - 1)
		end
	end, Lost(string.format(L("THE_GUILD_BANK_DID_NOT_HAND"), job.link)))
end

function StartNext()
	if job or using then return end
	local pick = table.remove(queue, 1)
	if not pick then return Finish() end

	if IsUnitInCombat("player") then
		ClearQueue()
		Print(L("NOT_DURING_COMBAT"))
		return
	end
	if GetItemId(pick.bag, pick.slot) ~= pick.itemId then return StartNext() end
	if GetNumBagFreeSlots(BAG_BACKPACK) < FreeSlotsFor(pick.bag) then
		local left = ClearQueue() + 1
		Print(string.format(L("YOUR_BACKPACK_IS_TOO_FULL_TO"), left))
		return Finish()
	end

	job = pick
	if pick.bag == BAG_GUILDBANK then
		job.guildId = GetSelectedGuildBankId()
		StartFromGuildBank()
	else
		StartFromBank()
	end
end

local function Enqueue(bag, slot)
	queue[#queue + 1] = { bag = bag, slot = slot, itemId = GetItemId(bag, slot), link = GetItemLink(bag, slot),
		keep = CategoryOf(bag, slot) == "furnishings" }
end

local function GetOne(bag, slot)
	if IsUnitInCombat("player") then
		Print(L("NOT_DURING_COMBAT"))
		return false
	end

	local link = GetItemLink(bag, slot)
	if AlreadyKnown(link, GetItemType(bag, slot)) then
		Print(string.format(L("IS_ALREADY_KNOWN_SO_IT_STAYS"), link))
		return true
	end

	Enqueue(bag, slot)
	StartNext()
	return true
end

local function StorageBags()
	if IsGuildBankOpen() then return { BAG_GUILDBANK } end
	if not IsBankOpen() then return {} end
	local bag = GetBankingBag()
	if bag == BAG_BANK then return { BAG_BANK, BAG_SUBSCRIBER_BANK } end
	return { bag }
end

local function GetAll()
	if not saved or not saved.enabled or not IsAnyBankOpen() then return false end
	if IsUnitInCombat("player") then
		Print(L("NOT_DURING_COMBAT"))
		return false
	end

	local seen = {}
	for _, entry in ipairs(held) do seen[entry.itemId] = true end
	for _, pick in ipairs(queue) do seen[pick.itemId] = true end
	if job then seen[job.itemId] = true end

	local added = 0
	for _, bag in ipairs(StorageBags()) do
		local slot = ZO_GetNextBagSlotIndex(bag)
		while slot do
			local itemId = GetItemId(bag, slot)
			if itemId ~= 0 and not seen[itemId] and CanTakeFrom(bag, slot) and PassesFilter(bag, slot) then
				seen[itemId] = true
				if not AlreadyKnown(GetItemLink(bag, slot), GetItemType(bag, slot)) then
					Enqueue(bag, slot)
					added = added + 1
				end
			end
			slot = ZO_GetNextBagSlotIndex(bag, slot)
		end
	end

	if added == 0 then
		Print(L("NOTHING_HERE_YOU_CAN_STILL_LEARN"))
		return true
	end
	Print(string.format(L("TAKING_ONE_EACH_OF_ITEM_ONE"), added, added == 1 and "" or "s"))
	batch = batch or { taken = 0, bag = open_storage }
	StartNext()
	return true
end

local function ReturnTo(matches)
	local stacked = {}
	for i = #saved.returns, 1, -1 do
		local entry = saved.returns[i]
		if matches(entry) then
			local guild = entry.bag == BAG_GUILDBANK
			local slot = FindInBackpack(entry.itemId, guild)
			if not slot then
				table.remove(saved.returns, i)
			else
				local link = GetItemLink(BAG_BACKPACK, slot)
				local sent
				if guild then
					TransferToGuildBank(BAG_BACKPACK, slot)
					sent = true
				else
					local target = StackTarget(entry.bag, entry.itemId)
					sent = target ~= nil and Move(BAG_BACKPACK, slot, entry.bag, target, 1)
					if sent then stacked[entry.bag] = true end
				end
				if sent then
					table.remove(saved.returns, i)
					Print(string.format(L("WENT_BACK"), link))
				end
			end
		end
	end
	for bag in pairs(stacked) do StackBag(bag) end
end

local function ResetToDefaults()
	for _, key in ipairs(SETTING_KEYS) do
		local value = DEFAULTS[key]
		if type(value) == "table" then value = ZO_DeepTableCopy(value) end
		saved[key] = value
	end
end

local function FilterRows()
	local rows = {}
	for _, q in ipairs(QUALITIES) do
		rows[#rows + 1] = { section = "qualities", key = q.key, label = q.label }
	end
	for _, t in ipairs(TYPES) do
		rows[#rows + 1] = { section = "types", key = t.key, label = t.label }
	end
	return rows
end

local function IsRowChecked(row) return saved.get_all[row.section][row.key] == true end
local function SetRowChecked(row, checked) saved.get_all[row.section][row.key] = checked == true end

local Toggle

local get_all_keybind = {
	alignment = KEYBIND_STRIP_ALIGN_CENTER,
	{
		name = GetString(SI_BINDING_NAME_OAPH_GET_ALL),
		keybind = GET_ALL_ACTION,
		callback = function() GetAll() end,
		visible = function() return saved and saved.enabled and not (open_storage and IsFurnitureVault(open_storage)) end,
	},
	{
		name = function() return saved and saved.enabled and L("TURN_OFF") or L("TURN_ON") end,
		keybind = TOGGLE_ACTION,
		callback = function() Toggle() end,
		visible = function() return saved ~= nil and not IsInGamepadPreferredMode() end,
	},
}

local get_all_shown = false

local function ShowGetAll()
	if get_all_shown then return end
	get_all_shown = true
	get_all_keybind[1].keybind = GetAllKeybind()
	PushActionLayerByName(KEYBIND_LAYER)
	KEYBIND_STRIP:AddKeybindButtonGroup(get_all_keybind)
end

local function HideGetAll()
	if not get_all_shown then return end
	get_all_shown = false
	RemoveActionLayerByName(KEYBIND_LAYER)
	KEYBIND_STRIP:RemoveKeybindButtonGroup(get_all_keybind)
end

local function OnInputModeChanged()
	if not get_all_shown then return end
	HideGetAll()
	ShowGetAll()
end

local function OnOpenBank(_, bankBag)
	open_storage = bankBag
	InstallPrimaryOverride()
	ShowGetAll()
	ReturnTo(function(entry)
		if entry.bag == BAG_GUILDBANK then return false end
		return entry.bag == bankBag or (bankBag == BAG_BANK and entry.bag == BAG_SUBSCRIBER_BANK)
	end)
end

local function OnGuildBankReady()
	open_storage = BAG_GUILDBANK
	InstallPrimaryOverride()
	ShowGetAll()
	local guildId = GetSelectedGuildBankId()
	if not CanUseGuildBank(guildId) then return end
	ReturnTo(function(entry) return entry.bag == BAG_GUILDBANK and entry.guildId == guildId end)
end

local function OnCloseBank()
	HideGetAll()
	local left = ClearQueue()
	if left > 0 then Print(string.format(L("THE_CLOSED_WITH_STILL_TO_TAKE"), StorageName(open_storage), left)) end
	open_storage = nil
	UninstallPrimaryOverride()
	if not job and not using and held[1] then UseNext() end
end

local function PrimaryTarget(actions)
	local primary = actions:GetAction(1, "primary")
	if not primary then return nil end
	local inventorySlot = actions.m_inventorySlot
	if not inventorySlot then return nil end
	local bag, slot = ZO_Inventory_GetBagAndIndex(inventorySlot)
	local withdraw = primary[1] == GetString(SI_ITEM_ACTION_BANK_WITHDRAW)
		or (IsFurnitureVault(bag) and primary[1] == GetString(SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG))
	if not withdraw then return nil end
	if not CanGetOne(bag, slot) then return nil end
	return bag, slot
end

local function TakeOverPrimary()
	local do_primary = ZO_InventorySlotActions.DoPrimaryAction
	local primary_name = ZO_InventorySlotActions.GetPrimaryActionName

	local override_primary = function(self, options)
		local bag, slot = PrimaryTarget(self)
		if bag and IsAlive() then
			GetOne(bag, slot)
			return true
		end
		return do_primary(self, options)
	end

	local override_name = function(self, options)
		local bag, slot = PrimaryTarget(self)
		if bag then
			if CategoryOf(bag, slot) == "furnishings" then return GetString(SI_OAPH_GET_ONE_FURNISHING) end
			return GetString(SI_OAPH_GET_ONE)
		end
		return primary_name(self, options)
	end

	InstallPrimaryOverride = function()
		ZO_InventorySlotActions.DoPrimaryAction = override_primary
		ZO_InventorySlotActions.GetPrimaryActionName = override_name
	end

	UninstallPrimaryOverride = function()
		ZO_InventorySlotActions.DoPrimaryAction = do_primary
		ZO_InventorySlotActions.GetPrimaryActionName = primary_name
	end
end

local function OnGamepadGuildWithdraw(screen)
	local target = screen:GetTargetData()
	if not target or target.currencyType or not target.itemData then return false end

	local bag, slot = target.itemData.bagId, target.itemData.slotIndex
	if not CanGetOne(bag, slot) then return false end
	GetOne(bag, slot)
	return true
end

local function HowItWorks()
	return string.format(L("HOW_IT_WORKS"), GetAllPhrase(), TogglePhrase())
end

local function ResetSettings()
	ResetToDefaults()
	Print(L("SETTINGS_ARE_BACK_TO_THEIR_DEFAULTS"), true)
end

local function PanelRows()
	local sections = {
		{ label = L("GET_ALL_QUALITY"), section = "qualities", rows = {} },
		{ label = L("GET_ALL_TYPES"), section = "types", rows = {} },
	}
	for _, block in ipairs(sections) do
		for _, row in ipairs(FilterRows()) do
			if row.section == block.section then
				block.rows[#block.rows + 1] = {
					label = row.label,
					get = function() return IsRowChecked(row) end,
					set = function(value) SetRowChecked(row, value) end,
					default = DEFAULTS.get_all[row.section][row.key],
				}
			end
		end
	end
	local on = {
		label = L("OVERRIDE_WITHDRAW_BUTTON"),
		get = function() return saved.enabled end,
		set = function(value) saved.enabled = value end,
		default = DEFAULTS.enabled,
	}
	local furnishings = {
		label = L("GET_ONE_FURNISHING"),
		get = function() return saved.furnishings end,
		set = function(value) saved.furnishings = value end,
		default = DEFAULTS.furnishings,
	}
	local chat = {
		label = L("CHAT_MESSAGES"),
		get = function() return saved.chat_messages end,
		set = function(value) saved.chat_messages = value end,
		default = DEFAULTS.chat_messages,
	}
	return on, sections, furnishings, chat
end

local function BuildKeyboardPanel(lam)
	local on, sections, furnishings, chat = PanelRows()
	local controls = {
		{ type = "description", title = L("HOW_IT_WORKS_TITLE"), text = HowItWorks },
		{ type = "checkbox", name = on.label, getFunc = on.get, setFunc = on.set, default = on.default },
		{ type = "checkbox", name = furnishings.label, getFunc = furnishings.get, setFunc = furnishings.set,
			default = furnishings.default, disabled = function() return not saved.enabled end },
		{ type = "checkbox", name = chat.label, getFunc = chat.get, setFunc = chat.set, default = chat.default },
	}
	for _, block in ipairs(sections) do
		local checks = {}
		for _, row in ipairs(block.rows) do
			checks[#checks + 1] = {
				type = "checkbox", name = row.label, getFunc = row.get, setFunc = row.set,
				default = row.default, width = "half",
			}
		end
		controls[#controls + 1] = { type = "submenu", name = block.label, controls = checks }
	end
	controls[#controls + 1] = {
		type = "button",
		name = RESET_LABEL,
		warning = L("PUTS_EVERY_SETTING_ON_THIS_PANEL"),
		isDangerous = true,
		func = ResetSettings,
	}

	lam:RegisterAddonPanel(PANEL_ID, {
		type = "panel",
		name = "|c9CD04COne APH a Time|r",
		displayName = "|c00FFFFOne APH a Time|r",
		author = "|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r",
		version = "2026.10.06.13.49",
		registerForRefresh = true,
		translation = "https://www.esoui.com/portal.php?id=360&a=featurereq",
		donation = "https://buymeacoffee.com/aph0nlc",
	})
	lam:RegisterOptionControls(PANEL_ID, controls)
end

local function BuildConsolePanel(lhas)
	local on, sections, furnishings, chat = PanelRows()
	local settings = {
		{ type = lhas.ST_LABEL, label = L("HOW_IT_WORKS_TITLE") },
		{ type = lhas.ST_LABEL, label = HowItWorks },
		{ type = lhas.ST_CHECKBOX, label = on.label, getFunction = on.get, setFunction = on.set, default = on.default },
		{ type = lhas.ST_CHECKBOX, label = furnishings.label, getFunction = furnishings.get, setFunction = furnishings.set,
			default = furnishings.default, disable = function() return not saved.enabled end },
		{ type = lhas.ST_CHECKBOX, label = chat.label, getFunction = chat.get, setFunction = chat.set, default = chat.default },
	}
	for _, block in ipairs(sections) do
		settings[#settings + 1] = { type = lhas.ST_SECTION, label = block.label }
		for _, row in ipairs(block.rows) do
			settings[#settings + 1] = {
				type = lhas.ST_CHECKBOX, label = row.label, getFunction = row.get, setFunction = row.set, default = row.default,
			}
		end
	end
	settings[#settings + 1] = { type = lhas.ST_SECTION, label = "", subMenu = false }
	settings[#settings + 1] = {
		type = lhas.ST_BUTTON,
		label = RESET_LABEL,
		buttonText = RESET_LABEL,
		clickHandler = function()
			ResetSettings()
			lhas:RefreshAddonSettings()
		end,
	}
	local panel = lhas:AddAddon("One APH a Time", { allowDefaults = false, allowRefresh = true })
	panel:AddSettings(settings)
end

local function BuildSettingsPanel()
	local console = not IsKeyboardUISupported()
	local library = console and LibHarvensAddonSettings or LibAddonMenu2
	if not library then
		if not saved.warned_no_settings then
			saved.warned_no_settings = true
			Print(string.format(L("IS_NOT_INSTALLED_SO_THERE_IS"), console and "LibHarvensAddonSettings" or "LibAddonMenu-2.0"), true)
		end
		return false
	end
	if console then
		BuildConsolePanel(library)
	else
		BuildKeyboardPanel(library)
	end
	return true
end

local function RelabelGamepadGuildWithdraw()
	local screen = GAMEPAD_GUILD_BANK
	local descriptor = screen and screen.withdrawKeybindStripDescriptor and screen.withdrawKeybindStripDescriptor[1]
	if not descriptor or descriptor.keybind ~= "UI_SHORTCUT_PRIMARY" then return false end
	if descriptor.oaph_relabelled then return true end
	descriptor.oaph_relabelled = true

	local original = descriptor.name
	descriptor.name = function(...)
		local target = screen:GetTargetData()
		local item = target and not target.currencyType and target.itemData
		if item and CanGetOne(item.bagId, item.slotIndex) then return GetString(SI_OAPH_GET_ONE) end
		if type(original) == "function" then return original(...) end
		return original
	end
	return true
end

function Toggle()
	if not saved then return false end
	saved.enabled = not saved.enabled
	if saved.enabled then
		Print(string.format(L("TOGGLE_ON"), GetAllPhrase()), true)
	else
		Print(L("OFF_WITHDRAW_TAKES_THE_WHOLE_STACK"), true)
	end
	if get_all_shown then KEYBIND_STRIP:UpdateKeybindButtonGroup(get_all_keybind) end
	local over = WINDOW_MANAGER:GetMouseOverControl()
	if over and over.slotControlType then ZO_InventorySlot_HandleInventoryUpdate(over) end
	return saved.enabled
end

local function ToggleChat()
	if not saved then return false end
	saved.chat_messages = not saved.chat_messages
	Print(L(saved.chat_messages and "CHAT_MESSAGES_ON" or "CHAT_MESSAGES_OFF"), true)
	return saved.chat_messages
end

local function Command(args)
	local word = zo_strlower(zo_strtrim(args or ""))
	if word == "chat" then return ToggleChat() end
	return Toggle()
end

local function Init()
	saved = ZO_SavedVars:NewAccountWide("OAPHSV", 1, GetWorldName() or "Default", DEFAULTS)

	TakeOverPrimary()
	ZO_PreHook(ZO_GuildBank_Gamepad, "ConfirmWithdrawal", OnGamepadGuildWithdraw)
	CreateDefaultActionBind(GET_ALL_ACTION, KEY_E, KEY_ALT, KEY_INVALID, KEY_INVALID, KEY_INVALID)
	CreateDefaultActionBind(TOGGLE_ACTION, KEY_D, KEY_ALT, KEY_INVALID, KEY_INVALID, KEY_INVALID)
	RelabelGamepadGuildWithdraw()
	GAMEPAD_GUILD_BANK_SCENE:RegisterCallback("StateChange", function(_, state)
		if state == SCENE_SHOWING then RelabelGamepadGuildWithdraw() end
	end)
	zo_callLater(BuildSettingsPanel, 0)

	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_OPEN_BANK, OnOpenBank)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GUILD_BANK_ITEMS_READY, OnGuildBankReady)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_BANK, OnCloseBank)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CLOSE_GUILD_BANK, OnCloseBank)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnInputModeChanged)

	SLASH_COMMANDS["/oneaphatime"] = Command
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
	if name ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
	Init()
end)

OAPH = {
	CanGetOne = CanGetOne,
	GetOne = GetOne,
	GetAll = GetAll,
	CategoryOf = CategoryOf,
	Toggle = Toggle,
	ToggleChat = ToggleChat,
	IsEnabled = function() return saved and saved.enabled end,
	IsBusy = function() return job ~= nil or using or queue[1] ~= nil end,
	GetHeldCount = function() return #held end,
	GetReturnCount = function() return saved and #saved.returns or 0 end,
}
