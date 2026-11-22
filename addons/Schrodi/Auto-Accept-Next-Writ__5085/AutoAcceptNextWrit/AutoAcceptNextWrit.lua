-- After turning in a Master Writ, automatically accept the next one that's
-- ready, instead of having to dig through the bag and open it by hand.
--
-- WritWorthy itself has a fully-built version of this (WritWorthy:AutoQuest()
-- in WritWorthy_AutoQuest.lua) - but the maintainer deliberately never ships
-- it: that file is commented out of WritWorthy.txt's load list ("Optional as
-- long as I refuse to publish the autoquest feature"), so WritWorthy.AutoQuest
-- doesn't exist at runtime and "/writworthy auto" is a silent no-op. So this
-- reimplements the "is this sealed writ already handled" scan ourselves,
-- using the same WritWorthyInventoryList data WritWorthy's own tooltip
-- ("WritWorthy: crafted") reads from.
--
-- The checkmark icon some sealed writs show in the bag isn't a base-game
-- feature - it's DolgubonsLazyWritCreator (optional) hooking
-- ZO_UpdateStatusControlIcons to post it, based on an OR of its own
-- craftedMasterWrits tracking and WritWorthy's completion state. We check
-- both of those same two sources below (same unique-id scheme, so no need
-- to go through DLWC's own icon code) rather than the icon itself.
local function isWritCompleted(bagId, slotIndex)
	local WW = WritWorthy
	local list = WritWorthyInventoryList and WritWorthyInventoryList.singleton
	if WW and list then
		local id = WW.UniqueID(bagId, slotIndex)
		local data = list:UniqueIDToInventoryData(id)
		if data and data.ui_is_completed == true then
			return true
		end
	end

	-- DolgubonsLazyWritCreator (optional) tracks its own crafted-writ
	-- completions separately - this is what actually drives the checkmark
	-- icon it posts onto the inventory slot (ZO_UpdateStatusControlIcons
	-- hook in its MasterWrits.lua). A writ crafted through DLWC's own flow
	-- rather than WritWorthy's LibLazyCrafting queue wouldn't show up in
	-- WritWorthy's data at all, so check DLWC's own record too, same as
	-- that icon does.
	if WritCreater and WritCreater.savedVarsAccountWide and WritCreater.savedVarsAccountWide.craftedMasterWrits then
		local uniqueId = Id64ToString(GetItemUniqueId(bagId, slotIndex))
		if WritCreater.savedVarsAccountWide.craftedMasterWrits[uniqueId] then
			return true
		end
	end

	return false
end

local function acceptNextReadyWrit()
	-- Turning in the previous writ leaves us sitting in the Rolis dialog/
	-- reward UI. Close it before trying to open the next sealed writ, or
	-- UseItem on it has nowhere to put its own dialog. (This is what
	-- SCENE_MANAGER:Toggle("hud") used to do, less precisely - EndInteraction
	-- is the purpose-built call for it, and it's the same one WritWorthy's
	-- own unshipped auto-quest code uses for this exact reason.)
	if IsInteracting() then
		EndInteraction(GetInteractionType())
	end

	-- WritWorthy only rebuilds this data when its own window is shown or
	-- refreshed - force that here since we're reacting to a game event, not
	-- the WritWorthy UI being open.
	if WritWorthyUI_Refresh then
		WritWorthyUI_Refresh()
	end

	for i = 0, GetBagSize(BAG_BACKPACK) do
		if GetItemType(BAG_BACKPACK, i) == ITEMTYPE_MASTER_WRIT then
			if isWritCompleted(BAG_BACKPACK, i) then
				zo_callLater(function() CallSecureProtected("UseItem", BAG_BACKPACK, i) end, 300)
				zo_callLater(function() AcceptOfferedQuest() end, 500)
				return true
			end
		end
	end

	return false
end

EVENT_MANAGER:RegisterForEvent("queueNextWrit", EVENT_QUEST_COMPLETE, function(_, questName, _, _, _, _, questType)
	zo_callLater(function()
		if questType ~= QUEST_TYPE_CRAFTING or not questName:find("Masterful") then
			return
		end
		acceptNextReadyWrit()
	end, 300)
end)

-- Manual trigger for testing, or for grabbing a ready writ without waiting
-- on a turn-in to fire the event above.
SLASH_COMMANDS["/aanwtest"] = function()
	if not acceptNextReadyWrit() then
		d("|c66CCFFAutoAcceptNextWrit:|r no ready writ found.")
	end
end

SLASH_COMMANDS["/ww"] = function()
	SLASH_COMMANDS["/writworthy"]("")
	SLASH_COMMANDS["/writworthy"]("mat")
	SCENE_MANAGER:OnToggleHUDUIBinding()
	WritWorthyInventoryList_EnqueueAll()
	WritWorthy_MatUI_Refresh()
end
