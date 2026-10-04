-- LawfulBehave.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

-- State flags
MSI.showMessageSkillsBlocked = false
MSI.libSkillBlockerLoaded = false
MSI.libZoneLoaded = false
MSI.libGetTextLoaded = false
MSI.statusChecked = false --If Player Loaded and LibZone is loaded, then true
MSI.inCombat = false
MSI.slashcommandDisableFeature = false
MSI.foundCriminalSkill = false
MSI.blockedSkillsList = {}  -- List of blocked skill IDs for quick lookup
MSI.blockedWerwolfSkillsList = {}  -- List of blocked werewolf skill IDs for quick lookup
MSI.blockedAbilities = {
		--Necromancer Skills--ENG
		["Spirit Guardian"] = {blocked = true , werewolf = false}, 
		["Spirit Mender"] = {blocked = true , werewolf = false}, 
		["Intensive Mender"] = {blocked = true , werewolf = false}, 

		["Sacrificial Bones"] = {blocked = true , werewolf = false}, 
		["Blighted Blastbones"] = {blocked = true , werewolf = false}, 
		["Grave Lord's Sacrifice"] = {blocked = true , werewolf = false}, 

		["Frozen Colossus"] = {blocked = true , werewolf = false}, 
		["Pestilent Colossus"] = {blocked = true , werewolf = false}, 
		["Glacial Colossus"] = {blocked = true , werewolf = false}, 

		["Skeletal Mage"] = {blocked = true , werewolf = false}, 
		["Skeletal Archer"] = {blocked = true , werewolf = false}, 
		["Skeletal Arcanist"] = {blocked = true , werewolf = false}, 

		["Bone Goliath Transformation"] = {blocked = true , werewolf = false}, 
		["Pummeling Goliath"] = {blocked = true , werewolf = false}, 
		["Ravenous Goliath"] = {blocked = true , werewolf = false}, 

		--Necromancer Skills--GER
		["Geistpfleger"] = {blocked = true , werewolf = false}, 
		["Geisterbeschützer"] = {blocked = true , werewolf = false}, 
		["Intensivpfleger"] = {blocked = true , werewolf = false}, 

		["Opferknochen"] = {blocked = true , werewolf = false}, 
		["Verdorbene Sprengknochen"] = {blocked = true , werewolf = false}, 
		["Opfer des Grabesfürsten"] = {blocked = true , werewolf = false}, 

		["Gefrorener Koloss"] = {blocked = true , werewolf = false}, 
		["Pestilenzkoloss"] = {blocked = true , werewolf = false}, 
		["Gletscherkoloss"] = {blocked = true , werewolf = false}, 

		["Skelett-Magier"] = {blocked = true , werewolf = false}, 
		["Skelett-Schütze"] = {blocked = true , werewolf = false}, 
		["Skelett-Arkanist"] = {blocked = true , werewolf = false}, 

		["Knochenhüne-Transformation"] = {blocked = true , werewolf = false}, 
		["Prügelnder Hüne"] = {blocked = true , werewolf = false}, 
		["Gefräßiger Hüne"] = {blocked = true , werewolf = false},
  
		-- Only thwart Ulti, because Transformation is allready Unlawful
		-- Werewolf Skills--ENG
		["Werewolf Transformation"] = {blocked = true , werewolf = true},
		["Pack Leader"] = {blocked = true , werewolf = true}, 
		["Werewolf Berserker"] = {blocked = true , werewolf = true},

		-- Werewolf Skills--GER
		["Werwolfverwandlung"] = {blocked = true , werewolf = true},
		["Rudelführer"] = {blocked = true , werewolf = true}, 
		["Werwolfberserker"] = {blocked = true , werewolf = true},

		--Vampire Skills--ENG
		["Blood Scion"] = {blocked = true , werewolf = false},
		["Swarming Scion"] = {blocked = true , werewolf = false},
		["Perfect Scion"] = {blocked = true , werewolf = false},

		["Blood Frenzy"] = {blocked = true , werewolf = false},
		["Sated Frenzy"] = {blocked = true , werewolf = false},
		["Simmering Frenzy"] = {blocked = true , werewolf = false},

		["Vampiric Drain"] = {blocked = true , werewolf = false},
		["Exhilarating Drain"] = {blocked = true , werewolf = false},
		["Drain Vigor"] = {blocked = true , werewolf = false},

		["Mist Form"] = {blocked = true , werewolf = false},
		["Elusive Mist"] = {blocked = true , werewolf = false},
		["Blood Mist"] = {blocked = true , werewolf = false} ,
		
		--Vampire Skills--GER
		["Blutspross"] = {blocked = true , werewolf = false},
		["Schwärmender Spross"] = {blocked = true , werewolf = false},
		["Perfekter Spross"] = {blocked = true , werewolf = false},

		["Blutraserei"] = {blocked = true , werewolf = false},
		["Gesättigte Raserei"] = {blocked = true , werewolf = false},
		["Siedende Raserei"] = {blocked = true , werewolf = false},

		["Vampirisches Entziehen"] = {blocked = true , werewolf = false},
		["Belebender Entzug"] = {blocked = true , werewolf = false},
		["Elan entziehen"] = {blocked = true , werewolf = false},

		["Nebelgestalt"] = {blocked = true , werewolf = false},
		["Flüchtiger Nebel"] = {blocked = true , werewolf = false},
		["Blutnebel"] = {blocked = true , werewolf = false}
		--[] = {blocked = true , werewolf = false},, -- Add more criminal skill Names here , LAST SKILL MUST NOT HAVE A COMMA AT THE END, OTHERWISE LUA WILL THROW AN ERROR
}

function MSI.InitZoneGeoLocLibrary()
	MSI.LZG = LibZone
	if not MSI.LZG then
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LZG_FAILURE)))
	else
		MSI.libZoneLoaded = true
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LZG_SUCCESS)))
	end
end

function MSI.InitSkillBlockLibrary()
	MSI.LSB = LibSkillBlocker
	if not MSI.LSB then
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LSB_FAILURE)))
	else
		MSI.libSkillBlockerLoaded = true
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LSB_SUCCESS)))
	end
end

function MSI.InitGetTextLibrary()
	MSI.LGT = LibGetText
	if not MSI.LGT then
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LGT_FAILURE)))
	else
		MSI.libGetTextLoaded = true
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LGT_SUCCESS)))
	end
end

local function inPvpOrPvEZone()
	if not MSI.LZG or not MSI.LZG.GetCurrentZoneAndGroupStatus then
		return nil
	end

	local pvp, delve, pub, groupDungeon, raid =
		MSI.LZG:GetCurrentZoneAndGroupStatus()

	return (pvp or delve or pub or groupDungeon or raid)
end

local function CleanAbilityName(name)
	return name:gsub("%^%a+", "")
end

local function LawfulBehave_IsAbilityCriminal(abilityName)
	abilityName = CleanAbilityName(abilityName)
	if MSI.blockedAbilities[abilityName] and MSI.blockedAbilities[abilityName].blocked == true then
		return true
	else
		return false
	end
end

local function LawfulBehave_IsAbilityWerewolf(abilityName)
	abilityName = CleanAbilityName(abilityName)
	if MSI.blockedAbilities[abilityName] and MSI.blockedAbilities[abilityName].werewolf == true then
		return true
	else
		return false
	end
end

local function LawfulBehave_DisableWhenInCombat()
	for id, _ in pairs(MSI.blockedSkillsList) do
		MSI.LSB.UnregisterSkillBlock("LawfulBehaveSurveillance", id)
	end
end

local function LawfulBehave_DisableWerewolfRestriction()
	for id, _ in pairs(MSI.blockedWerwolfSkillsList) do
		MSI.LSB.UnregisterSkillBlock("LawfulBehaveSurveillance", id)
	end
end

local function LawfulBehave_EnableWerewolfRestriction()
	for id, _ in pairs(MSI.blockedWerwolfSkillsList) do
		MSI.LSB.RegisterSkillBlock("LawfulBehaveSurveillance", id, nil, false)
	end
end

-- For Werewolf Transformation , we need to listen for the effect change event to re-enable the restriction when the player leaves Werewolf form
local function OnEffectChanged(_, changeType,_,effectName)
	if effectName == "De-Werewolf" and changeType == EFFECT_RESULT_FADED then
		--MSI.Print("d", "Player left Werewolf form, enable Restriction Again")
		LawfulBehave_EnableWerewolfRestriction()
	end
end

local function LawfulBehave_EnableWhenOutOfCombat()
	if not MSI.SVars.IsLawfulBehave then return end

	for id, _ in pairs(MSI.blockedSkillsList) do
		if MSI.blockedSkillsList[id] == true then
			MSI.LSB.RegisterSkillBlock("LawfulBehaveSurveillance", id, nil, false)
		end
	end
end

local function LawfulBehave_ShowCenterMessage(showMessage)
	if showMessage == nil then return end
	if not showMessage then return end --Return, because no Message needed
	MSI.ShowAnnounce(0, 3000, GetString(MSI_MOD_LAWFUL_BEHAVE_PRESERVES))
end

------------------------------------------------------------
--  METHODE : Check IF Friendly NPC are near and prevent crime actions if they are
------------------------------------------------------------
local function LawfulBehave_CheckEnemy()
	if DoesUnitExist("reticleover") then
		local reaction = GetUnitReaction("reticleover")
		return reaction == UNIT_REACTION_HOSTILE, reaction
	end
	return false, nil
end

local function GetBarAbilityIds(hotbar)
	local ids = {}

	local FIRST = ACTION_BAR_FIRST_NORMAL_SLOT or 3
	local LAST  = ACTION_BAR_LAST_NORMAL_SLOT  or 10

	for slot = FIRST, LAST do
		local abilityId = GetSlotBoundId(slot, hotbar)
		if abilityId and abilityId > 0 then
			table.insert(ids, abilityId)
		end
	end
	return ids
end

function LawfulBehave_InitiRegisterBlockSkills()
	--MSI.Print("d", "LawfulBehave: Initiating Skill Block Registration...")

	-- Scan both bars
	local frontBar = GetBarAbilityIds(HOTBAR_CATEGORY_PRIMARY)
	local backBar  = GetBarAbilityIds(HOTBAR_CATEGORY_BACKUP)

	--MSI.Print("d", "LawfulBehave: Having both Bars")

	-- Merge both bars
	local allBars = {}
	for _, id in ipairs(frontBar) do table.insert(allBars, id) end
	for _, id in ipairs(backBar) do table.insert(allBars, id) end

	--MSI.Print("d", "LawfulBehave: Merged Both Bars, Total Abilities: " .. tostring(#allBars))

	local inPvpOrPvE = inPvpOrPvEZone() -- Check Zone Status once before the loop
	--MSI.Print("d", "LawfulBehave: inPvpOrPvEZone: " .. tostring(inPvpOrPvE))

	MSI.foundCriminalSkill = false -- Reset flag before checking skills

	for _, abilityId in ipairs(allBars) do

		local abilityName = GetAbilityName(abilityId) -- Use GetAbilityName for the ability name
		--We use a hardcoded list of Criminal Skills

		--MSI.Print("d", "LawfulBehave: Checking Ability ID: " .. abilityId .. " Name: " .. tostring(abilityName))

		if abilityName and LawfulBehave_IsAbilityCriminal(abilityName) then
			MSI.foundCriminalSkill = true

			if not inPvpOrPvE then
				--MSI.Print("d", "LawfulBehave: Blocking Criminal Skill: " .. abilityName .. " (ID: " .. abilityId .. ")")
				MSI.LSB.RegisterSkillBlock("LawfulBehaveSurveillance", abilityId, nil, false)
				MSI.blockedSkillsList[abilityId] = true
				
				if LawfulBehave_IsAbilityWerewolf(abilityName) then
					--MSI.Print("d", "LawfulBehave: This is a Werewolf Skill, Blocking it as well.")
					MSI.blockedWerwolfSkillsList[abilityId] = true
				end

				MSI.showMessageSkillsBlocked = true
				MSI.foundCriminalSkill = true
			else
				MSI.blockedSkillsList[abilityId] = false
				MSI.showMessageSkillsBlocked = false
				--MSI.Print("d", "LawfulBehave: Not Blocking Criminal Skill in PvP/PVE Zone: " .. abilityName .. " (ID: " .. abilityId .. ")")
				MSI.LSB.UnregisterSkillBlock("LawfulBehaveSurveillance", abilityId)
			end
		end
	end
	
	if MSI.foundCriminalSkill then -- Found a Skill that should be informed about, then show message
		LawfulBehave_ShowCenterMessage(MSI.showMessageSkillsBlocked) -- Show message after checking all skills
	end
end

local function LawfulBehave_RunLibZoneStatus()
	if not (MSI.libZoneLoaded and MSI.IsPlayerLoaded and MSI.libSkillBlockerLoaded and MSI.libGetTextLoaded) then return end
	MSI.statusChecked = true
	LawfulBehave_InitiRegisterBlockSkills()
end

local function LBOptionState()
	MSI.Print("c", zo_strformat(GetString(MSI_MOD_LAWFUL_BEHAVE_STATE), (MSI.SVars.IsLawfulBehave and GetString(MSI_ADDON_ENABLED) or GetString(MSI_ADDON_DISABLED))))
	MSI.ShowCenterMsg(2468, [[icon_info.dds]], zo_strformat(GetString(MSI_MOD_LAWFUL_BEHAVE_STATE), (MSI.SVars.IsLawfulBehave and GetString(MSI_ADDON_ENABLED) or GetString(MSI_ADDON_DISABLED))))
end
function MSI.MSILawfulBehave()
	MSI.SVars.IsLawfulBehave = (not MSI.SVars.IsLawfulBehave)
	LBOptionState()
end

function MSI.InitModLawfulBehave()
	local function UnRegModuleEvents()
		EVENT_MANAGER:UnregisterForEvent("LawfulBehave_EffectChanged", EVENT_EFFECT_CHANGED)
		EVENT_MANAGER:UnregisterForEvent("LawfulBehave", EVENT_PLAYER_COMBAT_STATE)
	end
	local function RegModuleEvents()
		UnRegModuleEvents()
		EVENT_MANAGER:RegisterForEvent("LawfulBehave_EffectChanged", EVENT_EFFECT_CHANGED, OnEffectChanged)
		EVENT_MANAGER:RegisterForEvent("LawfulBehave", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat) -- Checks if in Combat 
		MSI.inCombat = inCombat
		if MSI.inCombat then LawfulBehave_DisableWhenInCombat() -- Disable Surveillance in Combat
		else LawfulBehave_EnableWhenOutOfCombat() -- Enable Surveillance outside of Combat	
			if IsPlayerInWerewolfForm() then --MSI.Print("d", "LawfulBehave: Player is in Werewolf Form After Combat")
				LawfulBehave_DisableWerewolfRestriction() -- Disable Werewolf Restriction after Combat, because Player is in Werewolf Form
			else --MSI.Print("d", "LawfulBehave: Player is NOT in Werewolf Form, After Combat")
		end end end)
	end
	if MSI.SVars.IsLawfulBehave and MSI.SVars.IsMSIActive then
		RegModuleEvents()
		LawfulBehave_RunLibZoneStatus()
		--MSI.Print("d", "Modul option change!! LawfulBehave Event registered")
	elseif not MSI.SVars.IsLawfulBehave or not MSI.SVars.IsMSIActive then
		UnRegModuleEvents()
		--MSI.Print("d", "Module disabled!! LawfulBehave Event unregistered")
	else
		UnRegModuleEvents()
		--MSI.Print("d", "MSI |c8B0000not|r Active!! LawfulBehave Event unregistered")
	end
end
--eof