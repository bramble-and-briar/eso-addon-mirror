local addonName = "Auto%sRecharge"
Recharge = {
	version				= "2.79",
    author				= "XanDDemoX, current: Baertram",
    name				= string.format(addonName, " "),
    displayName			= string.format(addonName, " "),
	eventName			= string.format(addonName, "_"),
    website				= "http://www.esoui.com/downloads/info1091-AutoRecharge.html#info",
	savedVarsName		= "AutoRecharge_SavedVariables",
    savedVarsVersion	= 2.1, --Changing this will reset all SavedVariables!
}
local Recharge = Recharge

Recharge.debug = false

Recharge.preChatTextRed = "|cDD2222AutoRecharge|r "
local eventName = Recharge.eventName
local eventSuffixCharge = "_INV_UPDATE_CHARGE"
local eventSuffixRepair = "_INV_UPDATE_REPAIR"

local PLAYER = "player"
local REPAIR
local CHARGE
local RECHARGE_BAG

Recharge._isPlayerCurrentlyDead = false
local isPlayerCurrentlyDead = Recharge._isPlayerCurrentlyDead
Recharge._isRepairCurrentlyActive = false
local isRepairCurrentlyActive = Recharge._isRepairCurrentlyActive

Recharge.noChargeChangeEvents = {}
Recharge.noDurabilityChangeEvents = {}

local _repairSlots		= {EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_BACKUP_OFF, EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST,EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_HAND, EQUIP_SLOT_FEET}
local _rechargeSlots	= {EQUIP_SLOT_MAIN_HAND,EQUIP_SLOT_OFF_HAND,EQUIP_SLOT_BACKUP_MAIN,EQUIP_SLOT_BACKUP_OFF}

local _slotText = {
	[EQUIP_SLOT_MAIN_HAND] 		= GetString(SI_EQUIPTYPE14),
	[EQUIP_SLOT_OFF_HAND] 		= GetString(SI_EQUIPTYPE7),
	[EQUIP_SLOT_BACKUP_MAIN] 	= GetString(SI_EQUIPSLOT20),
	[EQUIP_SLOT_BACKUP_OFF] 	= GetString(SI_EQUIPSLOT21),
	[EQUIP_SLOT_HEAD] 			= GetString(SI_EQUIPTYPE1),
	[EQUIP_SLOT_SHOULDERS] 		= GetString(SI_EQUIPTYPE4),
	[EQUIP_SLOT_CHEST] 			= GetString(SI_EQUIPTYPE3),
	[EQUIP_SLOT_WAIST] 			= GetString(SI_EQUIPTYPE8),
	[EQUIP_SLOT_LEGS] 			= GetString(SI_EQUIPTYPE9),
	[EQUIP_SLOT_HAND] 			= GetString(SI_EQUIPTYPE13),
	[EQUIP_SLOT_FEET] 			= GetString(SI_EQUIPTYPE10)
 }

local _prefix = "|c22DD22[AutoRecharge]|r "
Recharge.defaultSettings = {
	AccountWide							= false,
	chargeEnabled						= true,
	rechargeDelay						= 500,
	chargeDuringCombat					= false,
    minChargePercent					= 0.05,
    alertSoulGemsEmpty					= false,
    alertSoulGemsEmptyOnLogin			= true,
    alertSoulGemsSoonEmpty				= false,
    alertSoulGemsSoonEmptyThreshold		= 20,
	alertSoulGemsSoonEmptyOnLogin		= false,
	chargeOnWeaponChange				= false,
	chargeOnWeaponChangeOnlyInCombat	= true,

	repairEnabled						= true,
	repairDelay							= 500,
	repairDuringCombat					= false,
    minConditionPercent					= 0.05,
    alertRepairKitsEmpty				= false,
    alertRepairKitsEmptyOnLogin			= true,
	alertRepairKitsEmptyOnVendorOpen	= false,
	alertRepairKitsSoonEmpty			= false,
    alertRepairKitsSoonEmptyThreshold	= 10,
	alertRepairKitsSoonEmptyOnLogin		= false,
	alertRepairKitsSoonEmptyOnVendorOpen = false,

    showRepairKitsLeftAtVendor			= false,
    useRepairKitForItemLevel            = false,

	dontUseCrownRepairKits				= false,
	useCrownRepairKitsFirst				= false,
	useCrownSoulgemsFirst				= false,

    chatOutput							= true,
    chatOutputSuppressNothingMessages	= true,
}

local function println(...)
	local args = {...}
	for i,v in ipairs(args) do
		args[i] = tostring(v)
	end
	table.insert(args,1,_prefix)
	d(table.concat(args))
end
Recharge.Println = println

local function round(value,places)
	local s =  10 ^ places
	return math.floor(value * s + 0.5) / s
end

local function trim(str)
	if str == nil or str == "" then return str end 
	return (str:gsub("^%s*(.-)%s*$", "%1"))
end 

local function ARC_GetEquipSlotText(slot)
	return _slotText[slot]
end

local function ARC_IsPlayerDead(forceUpdate)
	forceUpdate = forceUpdate or false
	if isPlayerCurrentlyDead == nil or forceUpdate == true then isPlayerCurrentlyDead = IsUnitDead(PLAYER) end
	--Fix for IsUnitDead("player") end which maybe return false if directly called after/before player dead where the
	--durability of items change but player is not dead yet.
	local myCurrentPlayerHealth
	local wasDead = isPlayerCurrentlyDead
	if not isPlayerCurrentlyDead then
		myCurrentPlayerHealth = 0
		--Check the health of the player, if <= 0 then "player is dead"
		myCurrentPlayerHealth, _, _ = GetUnitPower(PLAYER, COMBAT_MECHANIC_FLAGS_HEALTH)
		if myCurrentPlayerHealth <= 0 then isPlayerCurrentlyDead = true end
	end
if Recharge.debug then d("[ARC]ARC_IsPlayerDead: " .. tostring(isPlayerCurrentlyDead) .. ", playerHealth: " ..tostring(myCurrentPlayerHealth) .. ", wasDead: " ..tostring(wasDead)) end
	return isPlayerCurrentlyDead
end
Recharge.IsPlayerDead = ARC_IsPlayerDead

--Check if we are in combat and if the setting disallows to proceed then,
--or if we are not in combat it will be allowed to proceed.
--returns true if allowed to proceed, false if not allowed
local function duringCombatCheck(repairOrRechargeDuringCombatSetting, inCombat)
	if inCombat == nil then inCombat = IsUnitInCombat(PLAYER) end
	if inCombat == true and repairOrRechargeDuringCombatSetting ~= nil then
		return repairOrRechargeDuringCombatSetting
	end
	return true
end

--Check if the BagId is the one of BAG_WORN (worn items), if the player is not currently dead,
--and if the "during combat" checks allow to proceed.
--returns true if allowed to proceed, false if not allowed
local function wornNotDeadAndNotInCombatChecks(bagId, repairOrRechargeDuringCombatSetting)
	local isDebugEnabled = Recharge.debug
	if bagId ~= BAG_WORN or ARC_IsPlayerDead() == true or
			duringCombatCheck(repairOrRechargeDuringCombatSetting, nil) == false then
if isDebugEnabled then d("<<<<noWornNoDeadNoDuringCombatCheck - NOT allowed!") end
		return false
	end
if isDebugEnabled then d("<<<<noWornNoDeadNoDuringCombatCheck - allowed") end
	return true
end

local function ARC_showAlertMessage(alertType, value)
	if not alertType then return false end
	if Recharge.debug then d("[ARC_showAlertMessage]alertType: " ..tostring(alertType) .. ", value: " ..tostring(value)) end

    local alertMsg
    local iconText
    if alertType == "repairKitsEmpty" then
    	alertMsg = GetString(ARC_ALERT_REPAIRKITS_EMPTY)
        iconText = zo_iconTextFormat("esoui/art/icons/quest_crate_001.dds", 48, 48, " ")
    elseif alertType == "repairKitsSoonEmpty" then
    	if not value then return end
    	alertMsg = zo_strformat(GetString(ARC_ALERT_REPAIRKITS_SOON_EMPTY), value)
        iconText = zo_iconTextFormat("esoui/art/icons/quest_crate_001.dds", 48, 48, " ")
    elseif alertType == "soulGemsEmpty" then
    	alertMsg = GetString(ARC_ALERT_SOULGEMS_EMPTY)
        iconText = zo_iconTextFormat("esoui/art/icons/soulgem_006_empty.dds", 48, 48, " ")
    elseif alertType == "soulGemsSoonEmpty" then
    	if not value then return end
    	alertMsg = zo_strformat(GetString(ARC_ALERT_SOULGEMS_SOON_EMPTY), value)
        iconText = zo_iconTextFormat("esoui/art/icons/soulgem_006_empty.dds", 48, 48, " ")
    end
    if alertMsg and alertMsg ~= "" then
		if Recharge.debug then d(">alertMsg: " ..tostring(alertMsg)) end
		--CENTER_SCREEN_ANNOUNCE:AddMessage(EVENT_SKILL_RANK_UPDATE, CSA_EVENT_SMALL_TEXT, nil, iconText .. Recharge.preChatTextRed .. alertMsg)
		local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.ANTIQUITIES_FANFARE_FAILURE)
		messageParams:SetText(iconText .. Recharge.preChatTextRed .. alertMsg)
		messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_OBJECTIVE_COMPLETED)
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end
end

local function ARC_checkThresholdOrEmpty(checkType, emptyOrThreshold, amount)
	if checkType == nil then return false end
    if emptyOrThreshold == nil then return false end
    if amount == nil then return false end
	local settings = Recharge.settings
	if Recharge.debug then d("[ARC_checkThresholdOrEmpty]checkType: " ..tostring(checkType) .. ", emptyOrThreshold: " ..tostring(emptyOrThreshold) ..  ", amount: " ..tostring(amount)) end

    if 		checkType == "repairKits" then
    	if emptyOrThreshold == true then
            if amount == 0 then
	        	ARC_showAlertMessage("repairKitsEmpty")
            end
        else
			if Recharge.debug then d(">threshold repair kits: " ..tostring(settings.alertRepairKitsSoonEmptyThreshold)) end
			if amount < settings.alertRepairKitsSoonEmptyThreshold then
                ARC_showAlertMessage("repairKitsSoonEmpty", amount)
            end
        end
    elseif 	checkType == "soulGems" then
    	if emptyOrThreshold == true then
            if amount == 0 then
                ARC_showAlertMessage("soulGemsEmpty")
            end
        else
			if Recharge.debug then d(">threshold soulgems: " ..tostring(settings.alertSoulGemsSoonEmptyThreshold)) end
			if amount < settings.alertSoulGemsSoonEmptyThreshold then
                ARC_showAlertMessage("soulGemsSoonEmpty", amount)
            end
        end
    end
end

local function ARC_GetSoulGemsCount()
    --Get the actual soul gems amount
    RECHARGE_BAG = RECHARGE_BAG or Recharge.Bag
    local gems = RECHARGE_BAG.GetSoulGems(BAG_BACKPACK)
    local gemsCount = #gems
    if gemsCount > 0 then
        gemsCount = 0
        for _, soulGemStack in pairs(gems) do
            gemsCount = gemsCount + soulGemStack.size
        end
    end
    return gemsCount, gems
end
--Recharge.GetSoulGemsCount = ARC_GetSoulGemsCount

local function ARC_GetRepairKitsCount()
    --Get the actual repair kits amount
    RECHARGE_BAG = RECHARGE_BAG or Recharge.Bag
	local kits = RECHARGE_BAG.GetRepairKits(BAG_BACKPACK)
	Recharge.kitsInInventoryBag = kits
    local kitsCount = #kits or 0
    if kitsCount > 0 then
        kitsCount = 0
        for _, repairKitsStack in pairs(kits) do
            kitsCount = kitsCount + repairKitsStack.size
        end
    end
    return kitsCount, kits
end
--Recharge.GetRepairKitsCount = ARC_GetRepairKitsCount

local function ARC_ChargeEquipped(chatOutput, inCombat, slotIndex)
    if IsUnitInCombat("player") then return end
    if not Recharge.settings or Recharge.settings.chargeEnabled ~= true then return end
    Recharge.settings.minChargePercent = 0.05
	CHARGE = CHARGE or Recharge.Charge
	chatOutput = chatOutput or false
	local abortedDueToDeath = ARC_IsPlayerDead()
	--Do not go on if the player is dead
	if abortedDueToDeath then return end

	local settings = Recharge.settings
	local gemsCount, gems = ARC_GetSoulGemsCount()
	if gemsCount == 0 then
		if settings.alertSoulGemsEmpty then
			if chatOutput  and not settings.chatOutputSuppressNothingMessages then
				println(GetString(ARC_ALERT_SOULGEMS_EMPTY))
			end
			if not inCombat then
				ARC_checkThresholdOrEmpty("soulGems", true, gemsCount)
			end
		end
		return
	end

	local total = 0
	local str

	for i, slot in ipairs(_rechargeSlots) do
		if HasItemInSlot(BAG_WORN, slot) then
			if slotIndex == nil or (slotIndex ~= nil and slotIndex == slot) then
				total, abortedDueToDeath = CHARGE.ChargeItem(BAG_WORN, slot, gems, settings.minChargePercent)
				if abortedDueToDeath == false and total > 0 and chatOutput then
					str = (str or GetString(ARC_CHATOUTPUT_CHARGED))..((str and ", ") or "")..ARC_GetEquipSlotText(slot).." ("..tostring(round(total,2)).." %)"
				end
				if abortedDueToDeath then return end
				--Slot to check was found, abort other slot checks
				if slotIndex ~= nil then break end
			end
		end
	end

	if str == nil and chatOutput and not settings.chatOutputSuppressNothingMessages then
		local charge,maxcharge
		for i,slot in ipairs(_rechargeSlots) do
			if HasItemInSlot(BAG_WORN, slot) then
				if slotIndex == nil or (slotIndex ~= nil and slotIndex == slot) then
					charge, maxcharge = GetChargeInfoForItem(BAG_WORN,slot)
					if maxcharge > 0 then
						str = (str or GetString(ARC_CHATOUTPUT_CHARGED_NOTHING))..((str and ", ") or "")..ARC_GetEquipSlotText(slot).." ("..tostring(round((charge / maxcharge) * 100,2)).." %)"
					end
					--Slot to check was found, abort other slot checks
					if slotIndex ~= nil then break end
				end
			end
		end
	end

	if str ~= nil and chatOutput then
		println(str)
	elseif str == nil and chatOutput and not settings.chatOutputSuppressNothingMessages then
		println(GetString(ARC_CHATOUPUT_NO_CHARGEABLE_WEAPONS))
	end

	if not inCombat and settings.alertSoulGemsSoonEmpty and not settings.alertSoulGemsSoonEmptyOnLogin then
        ARC_checkThresholdOrEmpty("soulGems", false, gemsCount)
	end
end
Recharge.ARC_ChargeEquipped = ARC_ChargeEquipped


local function resetRepair()
	isRepairCurrentlyActive = false
	return
end

--Repair the equipped item with the slotIndex. If slotIndex is nil: Repair all equipped items
local function ARC_RepairEquipped(chatOutput, inCombat, slotIndex)
    if IsUnitInCombat("player") then return end
    if not Recharge.settings or Recharge.settings.repairEnabled ~= true then return end
    Recharge.settings.minConditionPercent = 0.05
	REPAIR = REPAIR or Recharge.Repair
	chatOutput = chatOutput or false
	local isDebugEnabled = Recharge.debug
	--Is the Player dead?
	local abortedDueToDeath = ARC_IsPlayerDead()
if isDebugEnabled then d("[Recharge]RepairEquipped - isDead: " ..tostring(abortedDueToDeath) .. ", repairActive: " ..tostring(isRepairCurrentlyActive)  .. ", inCombat: " ..tostring(inCombat) ..", slotIndex: " ..tostring(slotIndex) ..", chatOutput: " ..tostring(chatOutput)) end
	--Do not go on if the player is dead
	if abortedDueToDeath then
if isDebugEnabled then d("<<ABORT - player is dead") end
		return resetRepair()
	end

	--Prevent multiple repair runs at the same time!
	if isRepairCurrentlyActive == true then
if isDebugEnabled then d("<<ABORT - Repair run is active") end
		return
	end
	isRepairCurrentlyActive = true

	local settings = Recharge.settings

	--Get the repair kits and their count
	local kitsCount, kits = ARC_GetRepairKitsCount()
	if kitsCount == 0 then
		if settings.alertRepairKitsEmpty then
			if chatOutput and not settings.chatOutputSuppressNothingMessages then
				println(GetString(ARC_ALERT_REPAIRKITS_EMPTY))
			end
			if not inCombat then
				ARC_checkThresholdOrEmpty("repairKits", true, kitsCount)
			end
		end
if isDebugEnabled then d("<<ABORT - Kits count is 0") end
		return resetRepair()
	end

	--Check each equipped item if it needs to be repaired
	--and output it's repaired condition to the chat (if enabled)
	--Delay each repair attempt by the settings chosen "delay between repair"
	-->If chat output is enabled the output will be delayed by the total delay needed to repair all + 25 milliseconds
	-->If a repair attempt is currently done (even if delayed) further more repair attempts are suppressed
	local total = 0
	local wasCrownRepairKitUsed = false
	local kitWasUsed            = false
	local newCondition = 0
	local chatOutputStr

	local minConditionPercent = settings.minConditionPercent

	--Currently not used as total functions need to be rewritten to support delays and
	--death checks with delay
	local delayBetweenRepair = settings.repairDelay
	local checkNextSlotDelay = 0
	local totalDelay = 0

	for _, slot in ipairs(_repairSlots) do
		--Only go on if no crown repair kit has repaired all already
		if not wasCrownRepairKitUsed and not abortedDueToDeath then
			if (slotIndex == nil or (slotIndex ~= nil and slotIndex == slot)) then
				--Check if the slot is equipped
				if HasItemInSlot(BAG_WORN, slot) then
					--First slot to check?
					if checkNextSlotDelay == 0 then

						if isDebugEnabled then d(">> ???????????????????????????????????????")
							d(">>Repair check, no delay, slot: " ..tostring(slot) .. "(".._slotText[slot]..")-" .. GetItemLink(BAG_WORN, slot)) end
						if not wasCrownRepairKitUsed and not abortedDueToDeath then
							--Prevent the repair try if a crown store repair kit was used already
							total, wasCrownRepairKitUsed, kitWasUsed, abortedDueToDeath, newCondition = REPAIR.RepairItem(BAG_WORN, slot, kits, minConditionPercent)
							--A repair kit was used?
							if not abortedDueToDeath and kitWasUsed then
								--Update the crown repair kit used flag
								if wasCrownRepairKitUsed == true then
									if isDebugEnabled then d("<<break loop -> Crown repair kit used") end
									totalDelay = 0
									break --leave the loop
								end
							elseif abortedDueToDeath then
								if isDebugEnabled then d("<<break loop -> Dead") end
								totalDelay = 0
								break --leave the loop
							end

							--Chat output needed? Append the output string, but only if no crown repair kit was used.
							-->Chat output text for crown repair kit usage will be done further down below
							if not abortedDueToDeath and chatOutput and not wasCrownRepairKitUsed and total > 0 and kitWasUsed then
								chatOutputStr = (chatOutputStr or GetString(ARC_CHATOUTPUT_REPAIRED))..((chatOutputStr and ", ") or "")..ARC_GetEquipSlotText(slot).." (+"..tostring(round(total,2)).." = " .. tostring(round(newCondition,2)) .. " %)"
							end
						else
							if isDebugEnabled then d("<<break loop -> Dead or crown repair kit used") end
							totalDelay = 0
							break --leave the loop
						end
						if isDebugEnabled then d("<< ???????????????????????????????????????") end

					else
						if isDebugEnabled then d("~~~> Registering repair check with delay: " ..tostring(checkNextSlotDelay)) end
						local currentLoopDelay = checkNextSlotDelay

						--All other further slots to check
						--Delay each slot check by the milliseconds repair delay chosen in the settings menu
						zo_callLater(function()
							if isDebugEnabled then d(">> !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
								d(">>Repair check, delayed by "..tostring(currentLoopDelay)..", next slot: " ..tostring(slot) .. "(".._slotText[slot]..")-" .. GetItemLink(BAG_WORN, slot)) end
							--Prevent the repair try if a crown store repair kit was used already
							if not wasCrownRepairKitUsed and not abortedDueToDeath then
								total, wasCrownRepairKitUsed, kitWasUsed, abortedDueToDeath, newCondition = REPAIR.RepairItem(BAG_WORN, slot, kits, minConditionPercent)
								--A repair kit was used?
								if not abortedDueToDeath and kitWasUsed then
									--Update the crown repair kit used flag
									if wasCrownRepairKitUsed then
										if isDebugEnabled then d("<<return delayed call -> Crown repair kit used") end
										totalDelay = 0
										return --end zo_callLater function
									end
								elseif abortedDueToDeath then
									if isDebugEnabled then d("<<return delayed call -> Dead") end
									totalDelay = 0
									return --end zo_callLater function
								end
							else
								if isDebugEnabled then d("<<return delayed call -> Dead or crown repair kit used") end
								totalDelay = 0
								return --end zo_callLater function
							end

							--Chat output needed? Append the output string, but only if no crown repair kit was used.
							-->Chat output text for crown repair kit usage will be done further down below
							if not abortedDueToDeath and chatOutput and not wasCrownRepairKitUsed and total > 0 and kitWasUsed then
								chatOutputStr = (chatOutputStr or GetString(ARC_CHATOUTPUT_REPAIRED))..((chatOutputStr and ", ") or "")..ARC_GetEquipSlotText(slot).." (+"..tostring(round(total,2)).." = " .. tostring(round(newCondition,2)) .. " %)"
							end
							if isDebugEnabled then d("<< !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!") end
						end, checkNextSlotDelay)

					end

					--Delay by n miliseconds between each repair attempt
					checkNextSlotDelay = checkNextSlotDelay + delayBetweenRepair

					--Update the total delay for the further checks and the chat output
					totalDelay = checkNextSlotDelay

				else
					if isDebugEnabled then d(">> 00000000000000000000000000000")
						d(">>Non equipped item, slot: " ..tostring(slot) .. "(".._slotText[slot]..")")
  					end
				end

				--Slot to check was checked, abort other slot checks
				if slotIndex ~= nil then
		if isDebugEnabled then d("<abort loop -> SlotIndex was checked, all other are irrelevant") end
					totalDelay = 0
					--Reset the "repair run" prevention variable so the next slotIndex check via durabilityChange can happen
					resetRepair()
					break
				end
			end
		else
if isDebugEnabled then d("<abort loop -> Crown repair kit used or dead") end
			totalDelay = 0
			break -- crown repait kit has repaired all already or the player is dead meawhile, abort the loop
		end
	end

if isDebugEnabled then d(">total delay: " ..tostring(totalDelay)) end

	--Prepare the chat output by checking all worn equipment's condition now, after the total repair delay was waited
	if chatOutput == true then
		totalDelay = totalDelay + 25 --add a small delay before the chat output
		--Do the other chat output now
		zo_callLater(function()
			isDebugEnabled = Recharge.debug
if isDebugEnabled then d(">>0000000000 Delayed chatOutput 0000000000000") end
			--Was a crown store repair kit used?
			-->Show the chat output for it as it was not done already above!
			if wasCrownRepairKitUsed then
if isDebugEnabled then d(">>>crown repair chat output") end
				chatOutputStr = GetString(ARC_CHATOUTPUT_REPAIRED) .. " " .. GetString(SI_GAMEPAD_REPAIR_ALL_SUCCESS) .. " (+100 = 100 %)"
			end

			--Show nothing repaired chat outpout too?
			local chatOutputSuppressNothingMessages = settings.chatOutputSuppressNothingMessages
			if chatOutputStr == nil and not chatOutputSuppressNothingMessages then
if isDebugEnabled then d(">>>nothing repaired chat output") end
				local condition
				for _, slot in ipairs(_repairSlots) do
					if HasItemInSlot(BAG_WORN, slot) then
						if slotIndex == nil or (slotIndex ~= nil and slotIndex == slot) then
							condition     = GetItemCondition(BAG_WORN,slot)
							chatOutputStr = (chatOutputStr or GetString(ARC_CHATOUTPUT_REPAIRED_NOTHING))..((chatOutputStr and ", ") or "")..ARC_GetEquipSlotText(slot).." (+0 = "..tostring(round(condition,2)).." %)"
							--Slot to check was found, abort other slot checks
							if slotIndex ~= nil then break end
						end
					end
				end
			end

			--Do the chat output now
			if chatOutputStr ~= nil then
				println(chatOutputStr)
			elseif chatOutputStr == nil and not chatOutputSuppressNothingMessages then
				println(GetString(ARC_CHATOUPUT_NO_REPAIRABLE_ARMOR))
			end
if isDebugEnabled then d("<<0000000000 Delayed chatOutput 0000000000000") end
		end, totalDelay)
	end

	--Do the "repair kits soon empty checks" delayed, after chat output was done (if enabled)
	-->but only if the "soon empty" warning should not only show at login/reloadui/zoning!
	if not inCombat and settings.alertRepairKitsSoonEmpty and not settings.alertRepairKitsSoonEmptyOnLogin then
		totalDelay = totalDelay + 10 --add 10 milliseconds
		zo_callLater(function()
if Recharge.debug then d(">>delayed call 3 - repair kits left output") end
			if not IsUnitInCombat(PLAYER) then
				ARC_checkThresholdOrEmpty("repairKits", false, kitsCount)
			end
		end, totalDelay)
	end

	--Reset the "repair is currently active" prevention variable
	totalDelay = totalDelay + 10 --add 10 milliseconds
	zo_callLater(function()
if Recharge.debug then d(">>delayed call 4 - reset the repair prevention variable") end
		resetRepair()
	end, totalDelay)
end
Recharge.ARC_RepairEquipped = ARC_RepairEquipped



local function ARC_CombatStateChanged(eventCode, inCombat)
if Recharge.debug then d("=========================================================")
	d("[ARC]CombatStateChanged inCombat: " ..tostring(inCombat)) end
	--No repair or recharge if dead - Get current state by forcing the update
	isPlayerCurrentlyDead = ARC_IsPlayerDead(true)
	if isPlayerCurrentlyDead == true then return end

	local settings = Recharge.settings
	local chatOutput = settings.chatOutput
	if settings.chargeEnabled == true then
		if duringCombatCheck(settings.chargeDuringCombat, inCombat) then
			ARC_ChargeEquipped(chatOutput, inCombat, nil)
		end
	end

	if settings.repairEnabled == true then
		if duringCombatCheck(settings.repairDuringCombat, inCombat) then
			ARC_RepairEquipped(chatOutput, inCombat, nil)
		end
	end
end

local function ARC_DeathStateChanged(isDead)
local isDebugEnabled = Recharge.debug
if isDebugEnabled then d(">>> ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
 	d("[ARC]DeathStateChanged-isDead: " ..tostring(isDead)) end
	isPlayerCurrentlyDead = isDead
	if not isDead then
		--Reset the "no charge/durability event" slotIndices
		Recharge.noChargeChangeEvents = {}
		Recharge.noDurabilityChangeEvents = {}
	end
if isDebugEnabled then d("<<< ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~") end
end

--EVENT_INVENTORY_SINGLE_SLOT_UPDATE: Item charge changed
-- (number eventCode, Bag bagId, number slotId, boolean isNewItem, ItemUISoundCategory itemSoundCategory, number inventoryUpdateReason, number stackCountChange)
local function ARC_Charge_Changed(eventCode, bagId, slotIndex)
	if Recharge.debug then d("[ARC_Charge_Changed]" .. GetItemLink(bagId, slotIndex)) end
	--Prevent charge change events for slotIndices which recently got charged and where the soul stone usage
	--triggered the charge change event
	if Recharge.noChargeChangeEvents[slotIndex] then
		Recharge.noChargeChangeEvents[slotIndex] = nil
		return
	end

	local settings = Recharge.settings
	--Fix IsUnitDead("player") end where the charge state changes but the player is not dead -> Charge starts -> Player is dead meanwhile
	--in system -> server kicks us because of message spamming as we try to charge something while we are dead
	--zo_callLater(function()
	--Is the setting enabled to check charges and recharge items during combat, and is the item currently worn?
	if not wornNotDeadAndNotInCombatChecks(bagId, settings.chargeDuringCombat) then return end

	--Check if the item needs to be recharged now
	ARC_ChargeEquipped(settings.chatOutput, true, slotIndex)
	--end, 1000)
end

--EVENT_INVENTORY_SINGLE_SLOT_UPDATE: Item durability changed
-- (number eventCode, Bag bagId, number slotId, boolean isNewItem, ItemUISoundCategory itemSoundCategory, number inventoryUpdateReason, number stackCountChange)
local function ARC_Durability_Changed(eventCode, bagId, slotIndex)
	--Fix IsUnitDead("player") end where the durabilty changes but the player is not dead -> Repair starts -> Player is dead meanwhile
	--in system -> server kicks us because of message spamming as we try to repair something while we are dead
	zo_callLater(function()
		local isDebugEnabled = Recharge.debug
if isDebugEnabled then d(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	d("[ARC_Durability_Changed]" .. GetItemLink(bagId, slotIndex)) end
		--Prevent durability change events for slotIndices which recently got repaired and where the repairKit usage
		--triggered the durability change event
		if Recharge.noDurabilityChangeEvents[slotIndex] then
if isDebugEnabled then d("<ABORTED - Durablity was changed by repairKit of this addon") end
			Recharge.noDurabilityChangeEvents[slotIndex] = nil
			return
		end

		local settings = Recharge.settings
		--Is the setting enabled to check durability and repair items during combat, and is the item currently worn?
		if not wornNotDeadAndNotInCombatChecks(bagId, settings.repairDuringCombat) then return end

		--Check if the item needs to be repaired now
		ARC_RepairEquipped(settings.chatOutput, true, slotIndex)
if isDebugEnabled then d("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<") end
	end, 100) --call slightly delayed
end

local function TryParseOnOff(str)
	local on = (str == "+" or str == "on" or str == "an" or str == "на") or false
	local off = (not on and (str == "-" or str == "off" or str == "aus" or str == "от")) or false
	if on == false and off == false then return nil end
	if on then return true end
	if off then return false end
	return nil
end
Recharge.TryParseOnOff = TryParseOnOff

local function TryParsePercent(str)
	local percent = tonumber(str)
	if percent ~= nil and percent >= 0 and percent <= 100 then return (percent / 100) end
	return nil
end
Recharge.TryParsePercent = TryParsePercent


local function reAnchorControl(control, anchorMode, anchorToControl, anchorMode2, pX, pY)
    if control == nil then return end
    control:ClearAnchors()
    control:SetAnchor(anchorMode, anchorToControl, anchorMode2, pX, pY)
end

local function ARC_buildAndAnchorTexture(parentControl, textureName, texturePath, pWidth, pHeight, pR, pG, pB, pA, pX, pY, anchorToControl, anchorMode, anchorMode2, withLabel, labelAnchorControl, labelAnchorMode, labelAnchorMode2, label_pWidth, label_pHeight, label_pR, label_pG, label_pB, label_pA, label_pX, label_pY)
    if parentControl == nil or textureName == nil or texturePath == nil or anchorToControl == nil or anchorMode == nil then return end
    if anchorMode2 == nil then anchorMode2 = anchorMode end
    withLabel = withLabel or false
    pWidth = pWidth or 32
    pHeight = pHeight or 32
    pR = pR or 1
    pG = pG or 1
    pB = pB or 1
    pA = pA or 1
    pX = pX or 0
    pY = pY or 0

    --Create the texture control now
    local anchorName = anchorToControl:GetName()
    if anchorName == nil then return end
    local control = WINDOW_MANAGER:GetControlByName(anchorName .. "_" .. textureName, "")
    if control == nil then
        control = WINDOW_MANAGER:CreateControl(anchorName .. "_" .. textureName, parentControl, CT_TEXTURE)
    end
    if control == nil then return end
    control:SetDimensions(pWidth, pHeight)
    control:SetTexture(texturePath)
    control:SetColor(pR, pG, pB, pA)
    control:SetDrawTier(DT_HIGH)
    control:SetDrawLayer(DT_HIGH)
    reAnchorControl(control, anchorMode, anchorToControl, anchorMode2, pX, pY)

    labelAnchorControl = labelAnchorControl or control
    labelAnchorMode2 = labelAnchorMode2 or labelAnchorMode
    label_pWidth = label_pWidth or 25
    label_pHeight = label_pHeight or 15
    label_pX = label_pX or 0
    label_pY = label_pY or 0
    label_pR = label_pR or 1
    label_pG = label_pG or 1
    label_pB = label_pB or 1
    label_pA = label_pA or 1
    local labelControl
    --Create label control for the texture too?
    if withLabel and labelAnchorControl ~= nil and labelAnchorMode ~= nil and labelAnchorMode2 ~= nil then
        labelControl = WINDOW_MANAGER:CreateControl(anchorName .. "_" .. textureName .. "_LABEL", control, CT_LABEL)
        labelControl:SetFont("ZoFontWinH3")
        labelControl:SetScale(1)
        labelControl:SetDrawLayer(DT_HIGH)
        labelControl:SetDrawTier(DT_HIGH)
        labelControl:SetDimensions(label_pWidth, label_pHeight)
        labelControl:SetColor(label_pR, label_pG, label_pB, label_pA)
        labelControl:ClearAnchors()
        labelControl:SetAnchor(labelAnchorMode, labelAnchorControl, labelAnchorMode2, label_pX, label_pY)
    end
    return control, labelControl
end

local function ARC_InventorySingleSlotUpdate(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
	if Recharge.debug then d("[ARC_InventorySingleSlotUpdate] bagId: " .. tostring(bagId) ..", slotId: " .. tostring(slotId) .. ", isNewItem: " .. tostring(isNewItem) .. ", inventoryUpdateReason: " .. tostring(inventoryUpdateReason) ..", storeWindowHidden: " .. tostring(ZO_StoreWindow:IsHidden()) .. ", showRepairKitsAtVendor: " .. tostring(Recharge.settings.showRepairKitsLeftAtVendor)) end

--[[
    INVENTORY_UPDATE_REASON_DEFAULT				= 0
    INVENTORY_UPDATE_REASON_DURABILITY_CHANGE	= 1
    INVENTORY_UPDATE_REASON_DYE_CHANGE			= 2
    INVENTORY_UPDATE_REASON_ITEM_CHARGE			= 3
    INVENTORY_UPDATE_REASON_PLAYER_LOCKED		= 4
]]

	--Settings to show repairkits in vendor panel active? Is the vendor shown? Bag and slot are given? Item was bought new?
	if inventoryUpdateReason ~= INVENTORY_UPDATE_REASON_DEFAULT or not Recharge.settings.showRepairKitsLeftAtVendor or bagId == nil or slotId == nil then return false end
    --Was a new repair kit bought or one sold (isNewItem == false then)? Then update the repair kits shown
	if (not ZO_StoreWindow:IsHidden() and IsItemRepairKit(bagId, slotId)) or (ZO_StoreWindow:IsHidden() and not ZO_PlayerInventory:IsHidden() and isNewItem == false) then
		--Get the label control of the texture
		if Recharge.storeWindowRepairKitsLeftTextureLabel ~= nil then
			local kitsCount = ARC_GetRepairKitsCount()
			Recharge.storeWindowRepairKitsLeftTextureLabel:SetText(kitsCount)
		end
	end
end

local function ARC_Open_Store()
	local settings = Recharge.settings
	if Recharge.debug then d("[ARC_Open_Store]Alert on open: " ..tostring(settings.alertRepairKitsEmptyOnVendorOpen)) end

	local alertRepairKitsEmptyOnVendorOpen = settings.alertRepairKitsEmptyOnVendorOpen
	local alertRepairKitsSoonEmptyOnVendorOpen = settings.alertRepairKitsSoonEmptyOnVendorOpen
	if alertRepairKitsEmptyOnVendorOpen == true or alertRepairKitsSoonEmptyOnVendorOpen == true then
		local kitsCount = ARC_GetRepairKitsCount()
		if Recharge.debug then d(">kitsCount: " ..tostring(kitsCount)) end
		local emptyOrThresHold = kitsCount == 0
		if alertRepairKitsSoonEmptyOnVendorOpen == true then
			emptyOrThresHold = false -- Show the soon empty message if relevant!
		end
		ARC_checkThresholdOrEmpty("repairKits", emptyOrThresHold, kitsCount)
    end

    if settings.showRepairKitsLeftAtVendor then
        local vendorRepairKitsTextureName = eventName .. "_VENDOR_REPAIRKITS"
        if not Recharge.storeWindowRepairKitsLeftTexture then
            --Recharge.storeWindowRepairKitsLeftTexture, Recharge.storeWindowRepairKitsLeftTextureLabel = ARC_buildAndAnchorTexture(ZO_StoreWindowMenu, vendorRepairKitsTextureName, "esoui/art/icons/quest_crate_001.dds", 48, 48, 1, 1, 1, 1, -345, -38, ZO_StoreWindowMenuBar, TOPLEFT, BOTTOMLEFT, true, nil, RIGHT, RIGHT, 50, 25, 1, 1, 1, 1, 50, 0)
			Recharge.storeWindowRepairKitsLeftTexture, Recharge.storeWindowRepairKitsLeftTextureLabel = ARC_buildAndAnchorTexture(ZO_StoreWindowMenu, vendorRepairKitsTextureName, "esoui/art/icons/quest_crate_001.dds", 32, 32, 1, 1, 1, 1, -355, 28, ZO_StoreWindowMenuBar, TOPLEFT, BOTTOMLEFT, true, nil, RIGHT, RIGHT, 50, 25, 1, 1, 1, 1, 50, 0)
        end
        if Recharge.storeWindowRepairKitsLeftTexture then
            Recharge.storeWindowRepairKitsLeftTexture:SetHidden(false)
			--Reanchor it if we are at a normal vendor, a siege vendor or a store opened form our helpers
			local isStoreEmpty = IsStoreEmpty()
            local canStoreRepair = CanStoreRepair()
            local isSiegeVendor = false
			if canStoreRepair then
				if isSiegeVendor then
					--Store is a siege vendor
                    reAnchorControl(Recharge.storeWindowRepairKitsLeftTexture, TOPLEFT, ZO_StoreWindowMenuBar, BOTTOMLEFT, -455, 28)
				else
					--Store is a normal vendor
                    reAnchorControl(Recharge.storeWindowRepairKitsLeftTexture, TOPLEFT, ZO_StoreWindowMenuBar, BOTTOMLEFT, -355, 28)
				end
            else
                if isStoreEmpty then
                    --Store is our local helper
                    reAnchorControl(Recharge.storeWindowRepairKitsLeftTexture, TOPLEFT, ZO_StoreWindowMenuBar, BOTTOMLEFT, -455, 28)
                else
                    --Store is a normal vendor
                    reAnchorControl(Recharge.storeWindowRepairKitsLeftTexture, TOPLEFT, ZO_StoreWindowMenuBar, BOTTOMLEFT, -355, 28)
                end
			end
            --Get the label control of the texture
            if Recharge.storeWindowRepairKitsLeftTextureLabel ~= nil then
                local kitsCount = ARC_GetRepairKitsCount()
                Recharge.storeWindowRepairKitsLeftTextureLabel:SetText(kitsCount)
                Recharge.storeWindowRepairKitsLeftTextureLabel:SetHidden(false)

				--Register the event inventory single slot update for new bought repair kits
				EVENT_MANAGER:RegisterForEvent(eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ARC_InventorySingleSlotUpdate)
            end
        end
    end
end

local function ARC_Close_Store()
    --UnRegister the event inventory single slot update for new bought repair kits
    EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    if not Recharge.settings.showRepairKitsLeftAtVendor then
		if Recharge.storeWindowRepairKitsLeftTexture and not Recharge.storeWindowRepairKitsLeftTexture:IsHidden() then
        	Recharge.storeWindowRepairKitsLeftTexture:SetHidden(true)
		end
		if Recharge.storeWindowRepairKitsLeftTextureLabel and not Recharge.storeWindowRepairKitsLeftTextureLabel:IsHidden() then
        	Recharge.storeWindowRepairKitsLeftTextureLabel:SetHidden(true)
		end
    end
end

local function LoadSettings()
	if Recharge.settings ~= nil then return end
	Recharge.settings = {}
	local worldName = GetWorldName()
	local svName = Recharge.savedVarsName
	local defaultSettings = Recharge.defaultSettings
	local settingsSubTabName = "Settings"

	--Recharge.settings = ZO_SavedVars:NewCharacterIdSettings(Recharge.savedVarsName, Recharge.savedVarsVersion, "Settings", Recharge.defaultSettings, nil)
	Recharge.settings = ZO_SavedVars:NewAccountWide(svName, 1, settingsSubTabName, defaultSettings, worldName)
	if not Recharge.settings.AccountWide then
		--Unlink the account wide SV tables from the reference variable so assigning the character SVs will overwrite the account wide data
		local svCopy = ZO_ShallowTableCopy(Recharge.settings)
		Recharge.settings = svCopy
		--Load character SV settings now and assign them to the settings reference variable, which points currently to a local copy of the account wide SVs
		Recharge.settings = ZO_SavedVars:NewCharacterIdSettings(svName, Recharge.savedVarsVersion, settingsSubTabName, defaultSettings, worldName)
		Recharge.settings.AccountWide = false --hard-set this at character settings
	end

	--Security handling of some variables
	if Recharge.settings.minConditionPercent == nil then
		Recharge.settings.minConditionPercent = defaultSettings.minConditionPercent
	elseif Recharge.settings.minConditionPercent < 0 or Recharge.settings.minConditionPercent >= 1 then
		Recharge.settings.minConditionPercent = defaultSettings.minConditionPercent
	end
	if Recharge.settings.minChargePercent == nil then
		Recharge.settings.minChargePercent = defaultSettings.minChargePercent
	elseif Recharge.settings.minChargePercent < 0 or Recharge.settings.minChargePercent >= 1 then
		Recharge.settings.minChargePercent = defaultSettings.minChargePercent
	end
end


-- Always enforce the user's console-only policy even with older saved variables.
local function ARC_EnforcePolicy()
    if not Recharge.settings then return end
    local sv = Recharge.settings
    sv.minChargePercent = 0.05
    sv.minConditionPercent = 0.05
    sv.chargeDuringCombat = false
    sv.repairDuringCombat = false
    sv.chargeOnWeaponChange = false
    sv.chargeOnWeaponChangeOnlyInCombat = false
end

local function ARC_Initialize()
	SLASH_COMMANDS["/ardebug"] = function(arg)
		Recharge.debug = not Recharge.debug
		d(Recharge.name .. ": debug mode = " ..tostring(Recharge.debug))
	end


	SLASH_COMMANDS["/arc"] = function(arg)
		local settings = Recharge.settings
		arg = trim(arg)
		if arg == nil or arg == "" then
			if ARC_IsPlayerDead() == true then return end
			ARC_ChargeEquipped(true, nil, nil)
		else
			local percent = TryParsePercent(arg)
			if percent ~= nil and percent >= 0 and percent < 1 then
				settings.minChargePercent = percent
				println(GetString(ARC_CHATOUPUT_MIN_CHARGE),tostring(percent * 100),"%")
			elseif percent ~= nil then
				println(zo_strformat(GetString(ARC_CHATOUPUT_INVALID_PERCENTAGE), (percent * 100)))
			else
				local enabled = TryParseOnOff(arg)
				if enabled ~= nil then
					settings.chargeEnabled = enabled
					println(GetString(ARC_CHATOUPUT_CHARGE), ((enabled and GetString(ARC_CHATOUPUT_SETTINGS_ENABLED)) or GetString(ARC_CHATOUPUT_SETTINGS_DISABLED)))
				end
			end
		end

	end

	SLASH_COMMANDS["/arp"] = function(arg)
		local settings = Recharge.settings
		arg = trim(arg)
		if arg == nil or arg == "" then
			if ARC_IsPlayerDead() == true then return end
            ARC_RepairEquipped(true, nil, nil)
		else
			local percent = TryParsePercent(arg)

			if percent ~= nil and percent >= 0 and percent < 1 then
				settings.minConditionPercent = percent
				println(GetString(ARC_CHATOUPUT_MIN_CONDITION),tostring(percent * 100),"%")
			elseif percent ~= nil then
				println(zo_strformat(GetString(ARC_CHATOUPUT_INVALID_PERCENTAGE), (percent * 100)))
			else
				local enabled = TryParseOnOff(arg)
				if enabled ~= nil then
					settings.repairEnabled = enabled
					println(GetString(ARC_CHATOUPUT_REPAIR),((enabled and GetString(ARC_CHATOUPUT_SETTINGS_ENABLED)) or GetString(ARC_CHATOUPUT_SETTINGS_DISABLED)))
				end
			end

		end
	end

end

local function OnActiveWeaponPairChanged(eventId, activeWeaponPair, locked)
	if Recharge.debug then d("[AutoRecharge]ActiveWeaponPairChanged-activeWeaponPair: " ..tostring(activeWeaponPair) .. ", locked: " ..tostring(locked)) end
	if locked then
		local settings = Recharge.settings
		if settings.chargeOnWeaponChange == true and ARC_IsPlayerDead() == false then
			local inCombat = IsUnitInCombat(PLAYER)
			if not inCombat and settings.chargeOnWeaponChangeOnlyInCombat == true then return end
			ARC_ChargeEquipped(settings.chatOutput, inCombat, nil)
		end
	end
end

local function ARC_Player_Activated(...)
	--EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
	local settings = Recharge.settings
	isPlayerCurrentlyDead = IsUnitDead(PLAYER)
	Recharge.noChargeChangeEvents = {}
	Recharge.noDurabilityChangeEvents = {}


	--On a weapon pair change: Recharge checks?
	if settings.chargeOnWeaponChange == true then
		EVENT_MANAGER:RegisterForEvent(eventName, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnActiveWeaponPairChanged)
	end

	--Soul gems check
    local alertSoulGemsEmptyOnLogin     = settings.alertSoulGemsEmptyOnLogin
	local alertSoulGemsSoonEmptyOnLogin = settings.alertSoulGemsSoonEmptyOnLogin
	if alertSoulGemsEmptyOnLogin == true or alertSoulGemsSoonEmptyOnLogin == true then
		local gemsCount = ARC_GetSoulGemsCount()
		local emptyOrThresHold = gemsCount == 0
		if alertSoulGemsSoonEmptyOnLogin == true then
			emptyOrThresHold = false --do not only check empty soulgems, but threshold too!
		end
		ARC_checkThresholdOrEmpty("soulGems", emptyOrThresHold, gemsCount)
    end

	--Repair kits check
    local alertRepairKitsEmptyOnLogin = settings.alertRepairKitsEmptyOnLogin
	local alertRepairKitsSoonEmptyOnLogin = settings.alertRepairKitsSoonEmptyOnLogin
	if alertRepairKitsEmptyOnLogin == true or alertRepairKitsSoonEmptyOnLogin == true then
		local kitsCount = ARC_GetRepairKitsCount()
		local emptyOrThresHold = kitsCount == 0
		if alertRepairKitsSoonEmptyOnLogin == true then
			emptyOrThresHold = false --do not only check empty kits, but threshold too!
		end
		ARC_checkThresholdOrEmpty("repairKits", emptyOrThresHold, kitsCount)
	end
end

local function ARC_Loaded(eventCode, addOnName)
	if(addOnName ~= "MyUI") then
		return
	end
	--Unregister this event again so it isn't fired again after this addon has beend recognized
	EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_ADD_ON_LOADED)
	LoadSettings()
    ARC_EnforcePolicy()
	Recharge.BuildSettingsMenu()

	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, ARC_Player_Activated)
	--Register for Store opened & closed
	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_OPEN_STORE,  ARC_Open_Store)
	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_CLOSE_STORE, ARC_Close_Store)

	--Items changed: Weapon charge (only worn items)
	local eventNameCharge = eventName .. eventSuffixCharge
	EVENT_MANAGER:RegisterForEvent(eventNameCharge, 	EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ARC_Charge_Changed)
	EVENT_MANAGER:AddFilterForEvent(eventNameCharge, 	EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_ITEM_CHARGE)
	EVENT_MANAGER:AddFilterForEvent(eventNameCharge, 	EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

	--Items changed: Durability of repairable items (only worn items)
	local eventNameRepair = eventName .. eventSuffixRepair
	EVENT_MANAGER:RegisterForEvent(eventNameRepair, 	EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ARC_Durability_Changed)
	EVENT_MANAGER:AddFilterForEvent(eventNameRepair, 	EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DURABILITY_CHANGE)
	EVENT_MANAGER:AddFilterForEvent(eventNameRepair, 	EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)

	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_COMBAT_STATE, ARC_CombatStateChanged)
	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_DEAD, 	function() ARC_DeathStateChanged(true) end)
	EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ALIVE, 	function() ARC_DeathStateChanged(false) end)

	ARC_Initialize()
end

--function to trigger the repair via keybind
function Recharge.Keybind_Repair()
	if ARC_IsPlayerDead() == false then
		LoadSettings()
		ARC_RepairEquipped(Recharge.settings.chatOutput, false, nil)
	end
end

--function to trigger the recharge via keybind
function Recharge.Keybind_Recharge()
	if ARC_IsPlayerDead() == false then
		LoadSettings()
		ARC_ChargeEquipped(Recharge.settings.chatOutput, false, nil)
	end
end

--Function to trigger the auto repair/recharge via keybind
function Recharge.Triggle_Action()
	if ARC_IsPlayerDead() == false then
		Recharge.Keybind_Recharge()
		Recharge.Keybind_Repair()
	end
end

EVENT_MANAGER:RegisterForEvent(eventName, EVENT_ADD_ON_LOADED, ARC_Loaded)
