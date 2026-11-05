local Recharge = Recharge
--local Bag = Recharge.Bag

--local ItemsData = Recharge.ItemsData
local isPlayerDead = Recharge.IsPlayerDead

local recharge = {}


local function IsItemAboveThreshold(bagId,slotIndex,minPercent)

	local charge,maxcharge = GetChargeInfoForItem(bagId,slotIndex)
	local isAbove = charge >= maxcharge or (minPercent ~= nil and (charge/maxcharge) > minPercent)
	
	return isAbove,charge,maxcharge
end

--[[
local function IsItemChargable(bagId,slotIndex)
	return not ItemsData.IsMasterWeapon(bagId,slotIndex)
end
]]

local function ChargeItem(bagId,slotIndex,gems,minPercent)
	if isPlayerDead() then return 0, true end

	local gem

	--local recharged = false
	--local total = 0

	local isAbove,charge,maxcharge = IsItemAboveThreshold(bagId,slotIndex,minPercent)

	if isAbove == true then return 0, false end --or IsItemChargable(bagId,slotIndex) == false then return 0, false end

	local oldcharge = charge

	if gem == nil then
		gem = gems[#gems]
	end

	if gem ~= nil then

		if isPlayerDead() then return 0, true end
		local amount = GetAmountSoulGemWouldChargeItem(bagId,slotIndex,gem.bag,gem.index)
		if amount <= 0 then return 0, false end

		-->Attention: This will fire EVENT_INVENTORY_SINGLE_SLOT_UPDATE with INVENTORY_UPDATE_REASON_ITEM_CHARGE and
		-->AutoRecharge will try to charge the item again then. So we need to set a preventer variable here
		Recharge.noChargeChangeEvents[slotIndex] = true
		ChargeItemWithSoulGem(bagId,slotIndex,gem.bag,gem.index)

		gem.size = gem.size - 1

		if gem.size < 1 then
			table.remove(gems)
		end

		if (charge + amount) < maxcharge then
			charge = charge + amount
		else
			charge = maxcharge
		end

	end

	return ((charge - oldcharge) / maxcharge) * 100, false
end

recharge.ChargeItem = ChargeItem

Recharge.Charge   = recharge
