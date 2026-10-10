AUI.Ability = {}
local START_BUTTON_INDEX = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local END_BUTTON_INDEX = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1

local gActiveProcEffects = {}

local abilityProcAssignment = {
	--[EffectID] {Stackcount}
--Sorcerer
	--Dark Magic
	[46327] = true,    	-- Crystal Fragments
--Nightblade
	[61902] = true,		-- Grim Focus
	[61905] = true,		-- Grim Focus
	
	[61919] = true,		-- Merciless Resolve
	[61920] = true,		-- Merciless Resolve
	
	[61927] = true,		-- Relentless Focus	
	[61928] = true,		-- Relentless Focus	
}

local gProcEffectsFromAbilityAsignList = 
{
-- [AbilityID] {EffectID}		
--Sorcerer
		--Dark Magic		
		[114716] = {46327}, 				-- Crystal Fragments
	
--Nightblade
		--Assassination		
		[61907] = {61902, 61905}, 			-- Grim Focus
		[61930] = {61919, 61920},			-- Merciless Resolve			
		[61932] = {61927, 61928}, 			-- Relentless Focus	
}

function AUI.Ability.GetProcInfo(_changeType, _effectId, _stackCount, _castByPlayer)
	local slotInfo = nil

	if _castByPlayer then
		slotInfo = 
		{
			["isProc"] = false,
			["procType"] = -1,
			["slotId"] = -1,
		}	
	
		if _changeType == EFFECT_RESULT_GAINED or _changeType == EFFECT_RESULT_UPDATED then
			if abilityProcAssignment[_effectId] then			
				for slotId = START_BUTTON_INDEX, END_BUTTON_INDEX do
					local abilityId = GetSlotBoundId(slotId)
					if gProcEffectsFromAbilityAsignList[abilityId] then	
						for _, effectId in pairs(gProcEffectsFromAbilityAsignList[abilityId]) do
							if effectId == _effectId then
								slotInfo.slotId = slotId
								slotInfo.isProc = true
								slotInfo.procType = 0								
								
								gActiveProcEffects[slotId] = true
								break
							end	
						end			
					end
				end
			end
		elseif _changeType == EFFECT_RESULT_FADED then
			for slotId = START_BUTTON_INDEX, END_BUTTON_INDEX do
				if gActiveProcEffects[slotId] then
					if abilityProcAssignment[_effectId] then			
						slotInfo.slotId = slotId
						slotInfo.isProc = true
						slotInfo.procType = 1	
			
						gActiveProcEffects[slotId] = nil
						break				
					end
				end
			end		
		end		
	end
	
	return slotInfo
end

function AUI.Ability.IsProcEffect(_effectId, _castByPlayer)
	if _castByPlayer then
		if abilityProcAssignment[_effectId] then
			return true		
		end
	end
	
	return false
end