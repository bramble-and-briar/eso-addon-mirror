local Util = DariansUtilities
Util.Ability = Util.Ability or { }
Util.Stacks = Util.Stacks or {}
local Stacks = Util.Stacks
Stacks.morphs = {}

-- function Stacks:HandleMorphRegister(value)
	-- if value and not Stacks.morphCheckRegistered then
		-- EVENT_MANAGER:RegisterForEvent(
			-- "StacksMorphCheck",
			-- EVENT_ABILITY_LIST_CHANGED,
			-- function()
				-- Stacks:UpdateMorphs()
			-- end
		-- )
		
		-- Stacks.morphCheckRegistered = true
	-- elseif not value and Stacks.morphs ~= {} and Stacks.morphCheckRegistered then
		-- EVENT_MANAGER:UnregisterForEvent(
			-- "StacksMorphCheck")
			
		-- Stacks.morphCheckRegistered = false
	-- end
-- end

local MORPH_IDS = {
	["FS"] = 114108,
	["GF"] = 61902,
}

function Stacks:CheckMorph(value)
	local morph = ""
	local _,index,_,_,_,_ = GetAbilityProgressionXPInfoFromAbilityId(MORPH_IDS[value])
	-- morphId = GetSkillAbilityIndicesFromProgressionIndex(index)
	local _,morphId,_ = GetAbilityProgressionInfo(index)
	if value == "FS" then
		if morphId == 1 then morph = "VS"
		elseif morphId == 2 then morph = "RS"
		else morph = "FS"
		end
		Stacks:UpdateMorphData(value, morph)
	elseif value == "GF" then
		if morphId == 1 then
			morph = "RF"
			CombatMetronome.StackTracker.SKILL_ATTRIBUTES.GF.activation = 4
		elseif morphId == 2 then
			morph = "MR"
			CombatMetronome.StackTracker.SKILL_ATTRIBUTES.GF.activation = 5
		else
			morph = "GF"
			CombatMetronome.StackTracker.SKILL_ATTRIBUTES.GF.activation = 5
		end
		Stacks:UpdateMorphData(value, morph)
	end
	return morph
end

--IDs for easy access

local IDS = {
	["Crux"] = 184220,
	["BA"] = 203447,
	["MW"] = 122658,
	["GF"] = {
		["GF"] = 122585,
		["MR"] = 122586,
		["RF"] = 122587,
	},
	["FS"] = {
		["FS"] = 114131,
		["RS"] = 117638,
		["VS"] = 117625,
	},
	["FI"] = 91416,
}

function Stacks:UpdateMorphData(ability, morph)
	-- for ability, morph in pairs(Stacks.morphs) do
		local morphUpdated = false
		-- local newMorph = self:CheckMorph(ability)
		if ability == "FS" then
			if self.morphs.FS and self.morphs.FS ~= morph then
				self.morphs.FS = morph
				morphUpdated = true
			end
			if morphUpdated and CombatMetronome and CombatMetronome.StackTracker then
				if CombatMetronome.StackTracker.UI and CombatMetronome.StackTracker.UI.FS then
					CombatMetronome.StackTracker.UI.FS.indicator.ApplyIcon()
				end
				CombatMetronome.StackTracker:Unregister("FS")												-- unregister old id
			end
		elseif ability == "GF" then
			if self.morphs.GF and self.morphs.GF ~= morph then
				self.morphs.GF = morph
				morphUpdated = true
			end
			if morphUpdated and CombatMetronome and CombatMetronome.StackTracker then
				if CombatMetronome.StackTracker.UI and CombatMetronome.StackTracker.UI.GF then
					CombatMetronome.StackTracker.UI.GF.indicator.ApplyIcon()
				end
				CombatMetronome.StackTracker:Unregister("GF")												-- unregister old id
			end
		end
	-- end
end

-- local cruxId = 184220
-- local bAId = { ["buff"] = 203447, ["ability"] = 24165,}
-- local mWId = { ["buff"] = 122658, ["ability"] = 20805,} -- 122729
-- local gFId = {
	-- ["GF"] = { ["buff"] = 122585, ["ability"] = 61902,},
	-- ["MR"] = { ["buff"] = 122586, ["ability"] = 61919,},
	-- ["RF"] = { ["buff"] = 122587, ["ability"] = 61927,},
	-- }
-- local fSId = {
	-- ["FS"] = { ["buff"] = 114131, ["ability"] = {
	-- [1] = 114108, [2] = 123683, [3] = 123685
	-- }},	
	-- ["RS"] = { ["buff"] = 117638, ["ability"] = {
	-- [1] = 117637, [2] = 123718, [3] = 123719
	-- }},
	-- ["VS"] = { ["buff"] = 117625, ["ability"] = {
	-- [1] = 117624, [2] = 123699, [3] = 123704
	-- }},
	-- }

		---------------------------------------
        ---- Store abilities on Actionbars ----
        ---------------------------------------

function Stacks:StoreAbilitiesOnActionBar()
    local actionSlots = {}  -- Create a table to store action slots
	
	local function IsAlreadyInList(id)
		for i, entry in ipairs(actionSlots) do
			if entry.id == id then return true end
		end
		return false
	end

    for j = 0, 1 do
        for i = 3, 8 do
            local actionSlot = {}  -- Create a new table for each action slot
			local slotType = GetSlotType(i, j)
            -- setmetatable(actionSlot, {__index = index})
            if slotType then
				actionSlot.place = tostring(i .. j)
				if slotType == ACTION_TYPE_CRAFTED_ABILITY then
					actionSlot.id = GetAbilityIdForCraftedAbilityId(GetSlotBoundId(i, j))
				else
					actionSlot.id = GetSlotBoundId(i, j)
				end
				if (actionSlot.id ~= 0) and not IsAlreadyInList(actionSlot.id) then
					actionSlot.icon = GetAbilityIcon(actionSlot.id)
					actionSlot.name = Util.Text.CropZOSString(GetAbilityName(actionSlot.id), "ability")
					local sType, index = GetSpecificSkillAbilityKeysByAbilityId(actionSlot.id)
					actionSlot.skillLine = GetSkillLineId(sType, index)

					table.insert(actionSlots, actionSlot)  -- Add the current action slot to the table
					if not Util.Ability.cache[actionSlot.id] then Util.Ability:ForId(actionSlot.id) end
				end
			end
        end
    end

    return actionSlots
end

	--------------------
	-- Stack Tracking --
	--------------------

function Stacks:GetCurrentNumStacksOnPlayer(skill)
	local stacks = {
		["Crux"] = 0,
		["BA"] = 0,
		["MW"] = 0,
		["GF"] = 0,
		["FS"] = 0,
		["FI"] = 0,
		["CW"] = 0,
	}
	
	local abilityToCheck
	if skill == "GF" and Stacks.morphs.GF then
		abilityToCheck = IDS.GF[Stacks.morphs.GF]
	elseif skill == "FS" and Stacks.morphs.FS then
		abilityToCheck = IDS.FS[Stacks.morphs.FS]
	elseif not (skill == "GF" or skill == "FS") then
		abilityToCheck = IDS[skill]
	else
		return 0
	end
	if abilityToCheck then
		for i=1,GetNumBuffs("player") do
			local _,_,_,_,stack,_,_,_,_,_,abilityId = GetUnitBuffInfo("player", i)
			if abilityId == abilityToCheck then
				if skill == "FI" then
					stacks[skill] = 1
					break
				end
				stacks[skill] = stack
			break 
			end
		end
	end
	-- end
	return stacks[skill]
end