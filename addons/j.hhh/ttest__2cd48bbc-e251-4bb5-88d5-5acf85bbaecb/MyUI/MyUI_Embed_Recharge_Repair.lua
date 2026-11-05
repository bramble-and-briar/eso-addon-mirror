local Recharge = Recharge

local isPlayerDead = Recharge.IsPlayerDead

local repair = {}

local function IsItemAboveConditionThreshold(bagId,slotIndex,minPercent)
    if bagId == nil or slotIndex == nil then return end
    local isDebugEnabled = Recharge.debug
    local itemLink = GetItemLink(bagId, slotIndex)
    local condition = GetItemCondition(bagId,slotIndex)
    local isAbove = (condition / 100) > minPercent
if isDebugEnabled then d("[IsItemAboveConditionThreshold]" ..itemLink ..", isAbove: " ..tostring(isAbove) ..", threshold: " .. tostring(minPercent) .. ", condition: " ..tostring(condition)) end

    --Is an item equipped at this slot? OffHand weapons (2hd) also count as
    --equipped (slotHasItem return true! So we need to check the itemLink as well)
    if bagId == BAG_WORN then
        local _, slotHasItem = GetEquippedItemInfo(slotIndex)
        if isDebugEnabled then d(">slotHasItem: " ..tostring(slotHasItem)) end
        if not slotHasItem then
            return true, 100
        end
    end
    if itemLink == nil or itemLink == "" then
if isDebugEnabled then d("<<ABORT! No itemlink") end
        return true, 100
    end
    return isAbove, condition
end

--[[
local function println(...)
	local args = {...}
	for i,v in ipairs(args) do
		args[i] = tostring(v)
	end 
	table.insert(args,1,_prefix) --_prefix = ???
	d(table.concat(args))
end
]]

local function tryToUseItem(bagId, slotIndex)
    local usable, onlyFromActionSlot = IsItemUsable(bagId, slotIndex)
    if usable and not onlyFromActionSlot then
        --ClearCursor()
        if IsProtectedFunction("UseItem") then
		    CallSecureProtected("UseItem", bagId, slotIndex)
	    else
		    UseItem(bagId, slotIndex)
	    end
        return true
    end
    return false
end

local function RepairItem(bagId,slotIndex,kits,minPercent)
    local isDebugEnabled = Recharge.debug
if isDebugEnabled then d("[Recharge]RepairItem - slotIndex: " ..tostring(slotIndex)) end
	if isPlayerDead() then return 0, false, false, true, 0 end

    --Do we have any repair kits?
	local count = #kits 
	if count < 1 then return 0, false, false, false, 0  end
	--Is the item's condition below the set threshold?
	local isAbove,condition = IsItemAboveConditionThreshold(bagId,slotIndex,minPercent)
	if isAbove == true then return 0, false, false, false, condition end

    --item can be repaired, so find a kit now!
    local amount = 0
    local kitsIndex = #kits or 0
    local foundKit = false

    local settings = Recharge.settings
    local useRepairKitForItemLevel = settings.useRepairKitForItemLevel
	local useCrownRepairKitsFirst = settings.useCrownRepairKitsFirst

	-- Use item level appropriate repair kit?
	if useRepairKitForItemLevel == true then
        --Get the item's link
        local link = GetItemLink(bagId,slotIndex,LINK_STYLE_DEFAULT)
        if link ~= nil then
            --Get the item's level
            local level = GetItemLinkRequiredLevel(link)
if isDebugEnabled then d(">use repair kit for item level: " ..tostring(level)) end
            --Find a kit which can do up to 90% repair -> Code by ESOUI.com user "simonhang"!
            while(kitsIndex > 0 and foundKit == false) do
                local kit = kits[kitsIndex]
                --println("item level:"..tostring(level).." kit tier:"..tostring(kit.tier))
                amount = GetAmountRepairKitWouldRepairItem(bagId,slotIndex,kit.bag,kit.index)
                --if (condition + amount >= 90) or ((kit.tier == math.floor(level/10)+1) and amount > 10) then
                if (kit.tier == math.floor(level/10)+1) and amount > 10 then
                    --Repair kit that would repair 90% was found
                    --It's given via the index kitsIndex!
                    foundKit = true
                else
                    kitsIndex = kitsIndex - 1
                end
            end
            --No kit that meets the requirements was found yet?
            if kitsIndex <= 0 and foundKit == false then
                --So use one of the other kits as fallback!
                kitsIndex = #kits or 0
                foundKit = true
            end
        end
    else
if isDebugEnabled then d(">using any repair kit - crown first: " ..tostring(useCrownRepairKitsFirst)) end
        foundKit = true -- Just tell the addon to go on by setting this variable to true
	end -- Use item level appropriate repair kit

    --Was a kit found that should be used?
    if foundKit == true and kitsIndex > 0 then
        local repairKitWasUsed = false
        --Get the repair kit by it's index (either the last one in the table,
        -- or the determined one for the current item's level, that needs to be repaired)
        local kit = kits[kitsIndex]
        if kit ~= nil then

            --Use CrownStore repair kits first?
            local isCrownStoreRepairKit = (IsItemNonCrownRepairKit(kit.bag,kit.index) == false) or false
            if isDebugEnabled then d(">starting repair attempt (min%: " ..tostring(minPercent) .. "/cond: " ..tostring(condition).."): " .. GetItemLink(bagId,slotIndex))
                d(">foundKit, isCrownRepair: " .. tostring(isCrownStoreRepairKit) .." - " ..GetItemLink(kit.bag,kit.index)) end

            local oldcondition = condition
            if isCrownStoreRepairKit == true then
                if isDebugEnabled then d(">>crown repair kit") end
                --Crown store repair kit will repair all equipped items to 100%
                amount = 100
                --Repair the item with the crown repair kit now, by using it
                if isPlayerDead() then return 0, false, false, true, condition end

                if tryToUseItem(kit.bag,kit.index) == true then
                    -->Attention: This will fire EVENT_INVENTORY_SINGLE_SLOT_UPDATE with INVENTORY_UPDATE_REASON_DURABILITY_CHANGE and
                    -->AutoRecharge will try to repair the item again then. So we need to set a preventer variable here
                    Recharge.noDurabilityChangeEvents[slotIndex] = true
                    repairKitWasUsed = true
                end
            else
                -- Use not the item level appropriate repair kit?
                -- We need to get the repair amount that the kit will do etc. then
                -- If the setting is enabled the amount was determined above already!
                if not useRepairKitForItemLevel then
                    amount = GetAmountRepairKitWouldRepairItem(bagId,slotIndex,kit.bag,kit.index)
                end
                if isDebugEnabled then d(">>normal repair kit") end

                if isPlayerDead() then return 0, false, false, true, condition end
                --Repair the item with the repair kit now
                -->Attention: This will fire EVENT_INVENTORY_SINGLE_SLOT_UPDATE with INVENTORY_UPDATE_REASON_DURABILITY_CHANGE and
                -->AutoRecharge will try to repair the item again then. So we need to set a preventer variable here
                Recharge.noDurabilityChangeEvents[slotIndex] = true
                RepairItemWithRepairKit(bagId,slotIndex,kit.bag,kit.index)
                repairKitWasUsed = true
            end

            if repairKitWasUsed == true then
                --Reduce the repair kits stacksize by 1
                kit.size = kit.size - 1
                --If no kits are left in teh stack, renmove the stack from the total kits table
                if kit.size < 1 then
                    table.remove(kits, kitsIndex)
                end
                --Calculate the new item condition by adding the amount the repair kit repaired it
                condition = condition + amount
                --Maximize the condition to 100%
                if condition > 100 then
                    condition = 100
                end
                if isDebugEnabled then d(">>repair kit used, amount: " ..tostring(amount) .. ", condition: " ..tostring(condition)) end
                --Return the difference the repair kit repaired!
                local repairedAmount = condition-oldcondition
                return repairedAmount, isCrownStoreRepairKit, repairKitWasUsed, false, condition
            end
            return 0, isCrownStoreRepairKit, repairKitWasUsed, false, condition
        end
    else
if isDebugEnabled then d("<Abort: No appropriate repair kit found!") end
    end

	return 0, false, false, false, condition
end

repair.RepairItem = RepairItem

Recharge.Repair   = repair