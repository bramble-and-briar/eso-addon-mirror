----------------------------------------
--[[ ESOA Datastore ]]-- 
----------------------------------------
-- INTERNAL Implementation API
-- Load/Save Player Data from Datastore
----------------------------------------


------------------------------
-- 
local SLOT_TYPE_REV = {
  EQUIP_SLOT_HEAD      = "Head",
  EQUIP_SLOT_NECK      = "Neck",
  EQUIP_SLOT_SHOULDERS = "Shoulders",
  EQUIP_SLOT_CHEST     = "Chest",
  EQUIP_SLOT_WAIST     = "Waist",
  EQUIP_SLOT_WRIST     = "Wrist",
  EQUIP_SLOT_FEET      = "Feet", --9
  EQUIP_SLOT_HAND      = "Hand",
  EQUIP_SLOT_LEGS      = "Legs",
  
  EQUIP_SLOT_BACKUP_MAIN   = "ScndMain",
  EQUIP_SLOT_BACKUP_OFF    = "ScndOff",
  EQUIP_SLOT_BACKUP_POISON = "ScndPoison",
  EQUIP_SLOT_OFF_HAND      = "OffHand",
  EQUIP_SLOT_POISON        = "MainPoison",
  EQUIP_SLOT_MAIN_HAND     = "MainHand",
  EQUIP_SLOT_RANGED        = "Ranged",
  
  EQUIP_SLOT_CLASS1  = "Class1",
  EQUIP_SLOT_CLASS2  = "Class2",
  EQUIP_SLOT_CLASS3  = "Class3",
  EQUIP_SLOT_COSTUME = "Costume",
  
  EQUIP_SLOT_RING1 = "Ring1",
  EQUIP_SLOT_RING2 = "Ring2",
  
  EQUIP_SLOT_NONE = "None",
}

------------------------------
-- INT
-- 
--("world","Vampire","Blood Ritual")
function EchoESOADatastore:FindAbility(mySkilllsSection,skillType,skillClass,skillName)
	EchoESOADatastore.debugMsg("FindAbility: skillType=",tostring(skillType)," skillClass=",tostring(skillClass) ," skillName=",tostring(skillName) )
	local retVal = nil
	if( mySkilllsSection~=nil and 
		mySkilllsSection[skillType]~=nil and 
		mySkilllsSection[skillType][skillClass]~=nil and
		mySkilllsSection[skillType][skillClass]["abilities"]~=nil and
		mySkilllsSection[skillType][skillClass]["abilities"][skillName]~=nil) then
			retVal = mySkilllsSection[skillType][skillClass]["abilities"][skillName]
	end
	--[[
	if( mySkilllsSection~=nil ) then
		EchoESOADatastore.outputMsg("FindAbility: 1")
		if( mySkilllsSection[skillType]~=nil ) then
			EchoESOADatastore.outputMsg("FindAbility: 2")
			if( mySkilllsSection[skillType][skillClass]~=nil ) then
				EchoESOADatastore.outputMsg("FindAbility: 3")
				if( mySkilllsSection[skillType][skillClass]["abilities"]~=nil ) then
					EchoESOADatastore.outputMsg("FindAbility: 4")
					if( mySkilllsSection[skillType][skillClass]["abilities"][skillName]~=nil ) then
						EchoESOADatastore.outputMsg("FindAbility: 5")
					end
				end
			end
		end
	end
	EchoESOADatastore.outputMsg("FindAbility: retVal=",tostring(retVal))
	]]
	return retVal
end

------------------------------
-- INT
-- Saves all Player data
function EchoESOADatastore.checkNullData(characterLineKey)
	local dName = GetDisplayName()
	--
	-- Lists
	--
	if EchoESOADatastore.svListDataAW.servers == nil then
		EchoESOADatastore.svListDataAW.servers = {}
	end
	if EchoESOADatastore.svListDataAW[dName] == nil then
		EchoESOADatastore.svListDataAW[dName] = {}
	end
	if EchoESOADatastore.svListDataAW[dName].players == nil then
		EchoESOADatastore.svListDataAW[dName].players = {}
	end
	--
	-- Characters
	--
	if(EchoESOADatastore.svCharDataAW.tracking == nil) then
		EchoESOADatastore.svCharDataAW.tracking = {}
	end
	if EchoESOADatastore.svCharDataAW.sections == nil then
		EchoESOADatastore.svCharDataAW.sections = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.bio == nil then
		EchoESOADatastore.svCharDataAW.sections.bio = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.stats == nil then
		EchoESOADatastore.svCharDataAW.sections.stats = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.skills == nil then
		EchoESOADatastore.svCharDataAW.sections.skills = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.tradeskills == nil then
		EchoESOADatastore.svCharDataAW.sections.tradeskills = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.xp == nil then
		EchoESOADatastore.svCharDataAW.sections.xp = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.power == nil then
		EchoESOADatastore.svCharDataAW.sections.power = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.riding == nil then
		EchoESOADatastore.svCharDataAW.sections.riding = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.skillpoints == nil then
		EchoESOADatastore.svCharDataAW.sections.skillpoints = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.achieve == nil then
		EchoESOADatastore.svCharDataAW.sections.achieve = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.currency == nil then
		EchoESOADatastore.svCharDataAW.sections.currency = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.ava == nil then
		EchoESOADatastore.svCharDataAW.sections.ava = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.pvp == nil then
		EchoESOADatastore.svCharDataAW.sections.pvp = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.infamy == nil then
		EchoESOADatastore.svCharDataAW.sections.infamy = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.location == nil then
		EchoESOADatastore.svCharDataAW.sections.location = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.research == nil then
		EchoESOADatastore.svCharDataAW.sections.research = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.bags == nil then
		EchoESOADatastore.svCharDataAW.sections.bags = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.buffs == nil then
		EchoESOADatastore.svCharDataAW.sections.buffs = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.researchtraits == nil then
		EchoESOADatastore.svCharDataAW.sections.researchtraits = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.special == nil then
		EchoESOADatastore.svCharDataAW.sections.special = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.companions == nil then
		EchoESOADatastore.svCharDataAW.sections.companions = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.equipment == nil then
		EchoESOADatastore.svCharDataAW.sections.equipment = {}
	end
	if EchoESOADatastore.svCharDataAW.sections.championpoints == nil then
		EchoESOADatastore.svCharDataAW.sections.championpoints = {}
	end
	
end

------------------------------
-- INT
-- Saves all Player data
function EchoESOADatastore.saveCurrentPlayerDataInt()
	-- Initial Data	
	local dName 	= GetDisplayName()
	local pName     = GetUnitName("player")
	local rName     = GetRawUnitName("player")   
	local pID       = GetCurrentCharacterId()
	local pServer   = GetWorldName()
	local playerKey = pID.."_".. pServer:gsub(" ","_")
	local pNow      = GetTimeStamp()--ZO_FormatClockTime()
	EchoESOADatastore.view.whoiamplayerKey = tostring(playerKey)
	-- GLOBALS -- add me to global lists
	EchoESOADatastore.checkNullData(playerKey)
	-- GLOBALS -- add Server to global lists
	EchoESOADatastore.svListDataAW.servers[dName] = pServer
	-- Setup PLAYER LIST
	if(EchoESOADatastore.svListDataAW[dName].players[playerKey] ==nil )  then
		EchoESOADatastore.svListDataAW[dName].players[playerKey] = {}
		--EchoESOADatastore.svListDataAW[dName].players[playerKey].category = "A"
	else
		--Check version	
		--[[
		local pVersion = EchoESOADatastore.svListDataAW[dName].players[playerKey].version
		if( pVersion~=nil )then
			if( pVersion~=EchoESOADatastore.version ) then		
				EchoESOADatastore.view.previousversion = EchoESOADatastore.altData.players[playerKey].previousversion = pVersion
			end
		end 
		]]
		--if( EchoESOADatastore.svListDataAW[dName].players[playerKey].category==nil) then
		--	EchoESOADatastore.svListDataAW[dName].players[playerKey].category = "A"
		--end
	end
	EchoESOADatastore.view.pNow = pNow
	EchoESOADatastore.svListDataAW[dName].players[playerKey].playerKey = playerKey
	EchoESOADatastore.svListDataAW[dName].players[playerKey].name = pName
	EchoESOADatastore.svListDataAW[dName].players[playerKey].server = pServer
	EchoESOADatastore.svListDataAW[dName].players[playerKey].savedate = EchoESOADatastore.view.pNow
	EchoESOADatastore.svListDataAW[dName].players[playerKey].lastlogin= EchoESOADatastore.view.pNow
	EchoESOADatastore.svListDataAW[dName].players[playerKey].version = EchoESOADatastore.version	
	if(EchoESOADatastore.svListDataAW[dName].players[playerKey].playersorder==nil) then
		ElderScrollsOfAlts.altData.playersorderlast                = ElderScrollsOfAlts.altData.playersorderlast + 1
		EchoESOADatastore.svListDataAW[dName].players[playerKey].playersorder = ElderScrollsOfAlts.altData.playersorderlast
	end
	--
	-- Account Level
	--
	if(EchoESOADatastore.svESOADataAW[dName]==nil) then
		EchoESOADatastore.svESOADataAW[dName] = {}
	end
	if(EchoESOADatastore.svESOADataAW[dName].ava==nil) then
		EchoESOADatastore.svESOADataAW[dName].ava = {}
		EchoESOADatastore.svESOADataAW[dName].ava.campaigns = {}
	end
	local accountAvaElem = EchoESOADatastore.svESOADataAW[dName].ava
	--
	if(EchoESOADatastore.svESOADataAW[dName].companions==nil) then
		EchoESOADatastore.svESOADataAW[dName].companions = {}
	end
	--
	--
	-- SAVE SECTIONS
	EchoESOADatastore.saveCurrentPlayerDataBio(   playerKey, EchoESOADatastore.svCharDataAW.sections.bio )	  
	EchoESOADatastore.saveCurrentPlayerDataStats( playerKey, EchoESOADatastore.svCharDataAW.sections.stats, pName, dName )
	EchoESOADatastore.saveCurrentPlayerDataSkills(playerKey, EchoESOADatastore.svCharDataAW.sections.skills )
	EchoESOADatastore.saveCurrentPlayerDataTradeSkills(playerKey, EchoESOADatastore.svCharDataAW.sections.tradeskills )
	EchoESOADatastore.saveCurrentPlayerDataXP(     playerKey, EchoESOADatastore.svCharDataAW.sections.xp )
	EchoESOADatastore.saveCurrentPlayerDataPower(  playerKey, EchoESOADatastore.svCharDataAW.sections.power )
	EchoESOADatastore.saveCurrentPlayerDataRiding( playerKey, EchoESOADatastore.svCharDataAW.sections.riding )	 
	EchoESOADatastore.saveCurrentPlayerDataBags(   playerKey, EchoESOADatastore.svCharDataAW.sections.bags )
	EchoESOADatastore.saveCurrentPlayerDataSkillpoints( playerKey, EchoESOADatastore.svCharDataAW.sections.skillpoints )
	EchoESOADatastore.saveCurrentPlayerDataAchieve(  playerKey, EchoESOADatastore.svCharDataAW.sections.achieve )
	EchoESOADatastore.saveCurrentPlayerDataCurrency( playerKey, EchoESOADatastore.svCharDataAW.sections.currency )
	EchoESOADatastore.saveCurrentPlayerDataAVA( playerKey, EchoESOADatastore.svCharDataAW.sections.ava )
	EchoESOADatastore.saveCurrentPlayerDataPVP( playerKey, EchoESOADatastore.svCharDataAW.sections.pvp )
	EchoESOADatastore.saveCurrentPlayerDataInfamy(   playerKey, EchoESOADatastore.svCharDataAW.sections.infamy )
	EchoESOADatastore.saveCurrentPlayerDataLocation( playerKey, EchoESOADatastore.svCharDataAW.sections.location )
	EchoESOADatastore.saveCurrentPlayerDataResearch( playerKey, EchoESOADatastore.svCharDataAW.sections.research )
	EchoESOADatastore.saveCurrentPlayerDataBuffs(    playerKey, EchoESOADatastore.svCharDataAW.sections.buffs )
	EchoESOADatastore.saveCurrentPlayerDataResearchtraits( playerKey, EchoESOADatastore.svCharDataAW.sections.researchtraits )
	--
	EchoESOADatastore.saveCurrentPlayerDataCompanions( playerKey, EchoESOADatastore.svCharDataAW.sections.companions )
	EchoESOADatastore.saveCurrentPlayerDataEquipment(  playerKey, EchoESOADatastore.svCharDataAW.sections.equipment )
	EchoESOADatastore.saveCurrentPlayerDataChampionPoints( playerKey, EchoESOADatastore.svCharDataAW.sections.championpoints )
	--
	EchoESOADatastore.saveCurrentPlayerDataSpecial( playerKey, EchoESOADatastore.svCharDataAW.sections.special, EchoESOADatastore.svCharDataAW.sections.buffs, EchoESOADatastore.svCharDataAW.sections.skills, EchoESOADatastore.svCharDataAW.sections.bio )
	EchoESOADatastore.saveCurrentPlayerDataBank(    playerKey, EchoESOADatastore.svListDataAW[dName] )
	--
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataSkills(playerKey, sectionElem)
	EchoESOADatastore.debugMsg("saveCurrentPlayerDataSkills")
	--
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	-- Resets all my data to current data
	playerElem.name = pName
	playerElem.baseranks = {}
	local playerRanksElem = playerElem.baseranks

	-- DEFAULTS --
	local skillType          = nil  
	local baseElem           = nil
	local outputUndiscovered = false
	--
	skillType = SKILL_TYPE_ARMOR 
	outputUndiscovered = true
	playerElem.armor = {}
	baseElem = playerElem.armor --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	skillType = SKILL_TYPE_WORLD 
	outputUndiscovered = false
	playerElem.world = {}
	baseElem = playerElem.world --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	skillType = SKILL_TYPE_CLASS 
	outputUndiscovered = false
	playerElem.class = {}
	baseElem = playerElem.class --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	skillType = SKILL_TYPE_GUILD  
	outputUndiscovered = false
	playerElem.guild = {}
	baseElem = playerElem.guild --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	skillType = SKILL_TYPE_RACIAL  
	outputUndiscovered = false
	playerElem.racial = {}
	baseElem = playerElem.racial --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	skillType = SKILL_TYPE_WEAPON  
	outputUndiscovered = false
	playerElem.weapon = {}
	baseElem = playerElem.weapon --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	skillType = SKILL_TYPE_AVA  
	outputUndiscovered = false
	playerElem.ava = {}
	baseElem = playerElem.ava --.typelist
	EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	--
	--SKILL_TYPE_NONE TODO ?
	--
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataTradeSkills(playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	playerElem.baseranks = {}
	local baseRanks = playerElem.baseranks
	-- DEFAULTS --
	local skillType          = nil  
	local baseElem           = nil
	local outputUndiscovered = false
	-- TRADESKILLS
	skillType = SKILL_TYPE_TRADESKILL 
	outputUndiscovered = true  
	--
	local numSkillLines = GetNumSkillLines(skillType)
	for ii = 1, numSkillLines do
		--name, number rank, boolean discovered, number skillLineId, boolean advised, unlockText
		local name, rank, discovered, skillLineId, advised, unlockText = GetSkillLineInfo(skillType,ii)
		if name == nil then
			name = ii;
		end
		playerElem[name]		= {}
		playerElem[name].info	= {}
		playerElem[name].subskills	= {}
		local parentElem 	= playerElem[name]
		local infoElem 		= playerElem[name].info
		local subskillElem 	= playerElem[name].subskills
		local numAbilities = GetNumSkillAbilities(skillType, ii)
		infoElem.name = name
		infoElem.idx  = ii	
		infoElem.rank = rank
		infoElem.numAbilities = numAbilities
		infoElem.skillLineId = skillLineId
    
		local lastRankXP, nextRankXP, currentXP  = GetSkillLineXPInfo( skillType, ii )
		infoElem.lastRankXP = lastRankXP
		infoElem.nextRankXP = nextRankXP
		infoElem.currentXP  = currentXP
		baseRanks[name] = rank
		--
		EchoESOADatastore.SaveDataPlayerTradeDetails( name, infoElem, subskillElem, skillType, ii, numAbilities )
	end
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataStats(playerKey, sectionElem, pName, sName )
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	playerElem.name    = pName
	playerElem.account = sName
	--
	local current, max, effectiveMax 
	current, max, effectiveMax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_STAMINA)
	playerElem["stamina"] = max
	current, max, effectiveMax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH)
	playerElem["health"] = max
	current, max, effectiveMax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MAGICKA)
	playerElem["magicka"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_POWER)
	playerElem["power"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_WEREWOLF)
	playerElem["werewolf"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_FERVOR)
	playerElem["fervor"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_COMBO)
	playerElem["combo"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_CHARGES)
	playerElem["charges"] = max
	current, max, effectiveMax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
	playerElem["ultimate"] = max
	current, max, effectiveMax = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
	playerElem["mountstamina"] = max
	
	--
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataSpecial( playerKey, sectionElem, buffsSection, skillsSection, bioSection )
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	local myBioSection     = bioSection[playerKey]
	local mySkilllsSection = skillsSection[playerKey]
	--
	--Check Specific Skilllines for --Werewolf or Vampire--
	if(mySkilllsSection~=nil and mySkilllsSection.world~=nil) then
		for key,value in pairs(mySkilllsSection.world) do
			--print(key,value)
			if key == "Werewolf" then
				myBioSection.Werewolf = true
			elseif key == "Vampire" then
				myBioSection.Vampire  = true
			end
		end
	end	
	----Section: Special section
	if( myBioSection.Vampire == true) then
		EchoESOADatastore:SaveDataVampire( playerKey, playerElem, buffsSection, mySkilllsSection )
	end
	if( myBioSection.Werewolf == true) then
		EchoESOADatastore:SaveDataWerewolf( playerKey, playerElem, buffsSection, mySkilllsSection )
	end
end

------------------------------
-- INT
function EchoESOADatastore:SaveDataWerewolf(playerKey, baseElem, buffsSection, mySkilllsSection)
	EchoESOADatastore.debugMsg("SaveDataWerewolf: playerKey= " .. tostring(playerKey) )
	baseElem.werewolf = true
	--TODO replace with GetString(ESOA_BITE_WERE_NAME),GetString(ESOA_SKILL_WORLD),
	EchoESOADatastore:SaveDataSpecialBite(playerKey, baseElem, buffsSection,mySkilllsSection, "world","Werewolf",EchoESOADatastore.BITE_WERE_ABILITY,EchoESOADatastore.BITE_WERE_COOLDOWN)
end

------------------------------
-- INT
function EchoESOADatastore:SaveDataVampire(playerKey, baseElem, buffsSection, mySkilllsSection)
	EchoESOADatastore.debugMsg("SaveDataVampire: playerKey= " .. tostring(playerKey) )
	baseElem.vampire = true
	EchoESOADatastore:SaveDataSpecialBite(playerKey, baseElem, buffsSection,mySkilllsSection, "world","Vampire",EchoESOADatastore.BITE_VAMP_ABILITY,EchoESOADatastore.BITE_VAMP_COOLDOWN)
end

------------------------------
-- INT
function EchoESOADatastore:SaveDataSpecialBite(playerKey, baseElem, buffsSection,mySkilllsSection, skillineName, specialSkillName, abilityname, buffcooldown)
	-- 
	EchoESOADatastore.debugMsg("SaveDataSpecialBiteplayerKey= " .. tostring(playerKey) )
	--Has to have this ability to be able to BITE!
	EchoESOADatastore.debugMsg("SaveDataSpecialBite: skillineName=",tostring(skillineName)," specialSkillName=",tostring(specialSkillName) ," abilityname=",tostring(abilityname)," buffcooldown=",tostring(buffcooldown)  )
	local foundItem = EchoESOADatastore:FindAbility( mySkilllsSection, skillineName, specialSkillName, abilityname)
	EchoESOADatastore.debugMsg("SaveDataSpecialBite: foundItem= " .. tostring(foundItem) )
	if(foundItem==nil) then
		return
	end
	baseElem.biteability = abilityname
	--
	local myBuffsSection = buffsSection[playerKey]
	local fedBuff  = myBuffsSection[buffcooldown]
	EchoESOADatastore.debugMsg("SaveDataSpecialBite: fedBuff= " .. tostring(fedBuff) )
	--
	baseElem.buffName  = buffcooldown
	baseElem.fedBuff   = fedBuff
	baseElem.expiresAt = nil
	if(fedBuff==nil) then
		return
	end
	--
	local expiresAt   = fedBuff.expiresAt
	EchoESOADatastore.debugMsg("SaveDataSpecialBite: expiresAt= " .. tostring(expiresAt) )
	baseElem.expiresAt = expiresAt
	--
	--Time in seconds left till expires
	--local timeDiff = GetDiffBetweenTimeStamps( expiresAt, GetTimeStamp() )
	--EchoESOADatastore.debugMsg("Buff timeDiff=".. tostring(timeDiff) )
	--local timeTillReady = GetTimeStamp() + timeRemainingSecs
	--UUU
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataBio( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]

	local pName     = GetUnitName("player")
	local rName     = GetRawUnitName("player")   
	local pID       = GetCurrentCharacterId()
	local pServer   = GetWorldName()

	playerElem.name    = pName
	playerElem.rawname = rName  
	playerElem.id      = pID
	playerElem.server  = pServer  
	local pGender = GetUnitGender("player")
	playerElem.gender = pGender
	local pLvl = GetUnitLevel("player")
	playerElem.level = pLvl
	local canChampPts = CanUnitGainChampionPoints("player")
	playerElem.CanChampPts = canChampPts  
	if CanChampPts then
	--TODO Not sure what effective level means
	--playerElem.level    = GetUnitEffectiveLevel("player") 
	playerElem.champion = GetUnitChampionPoints("player")   
	end  
	local pRace = GetUnitRace("player")
	playerElem.race = pRace
	--GetUnitRaceId(string unitTag)
	local pClass = GetUnitClass("player")
	playerElem.class = pClass
	local pClassId = GetUnitClassId("player")
	playerElem.classId = pClassId
	local pAlliance = GetUnitAlliance("player")
	playerElem.alliance = pAlliance

	--Werewolf or Vampire
	playerElem.Werewolf = false
	playerElem.Vampire  = false
	--	
	playerElem.secondsPlayed = GetSecondsPlayed()
	playerElem.zone = GetUnitZone("player")
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataXP( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	local canChampPts = CanUnitGainChampionPoints("player")
	playerElem.canchamppts = canChampPts  
	playerElem.champion = nil
	if canChampPts then
		--TODO Not sure what effective level means
		playerElem.efflevel = GetUnitEffectiveLevel("player") 
		playerElem.champion = GetUnitChampionPoints("player")   
	end
	local xpleft    = GetNumExperiencePointsInLevel(pLvl)
	--if not xpleft then
		--d("You can't level up any further.")
	-- It takes " .. xpleft .. " XP to get from the start of this level to the next level.
	playerElem.xpleft = xpleft
	--
	playerElem.unitxp    = GetUnitXP("player")
	playerElem.unitxpmax = GetUnitXPMax("player")
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataPower( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	local current, max, effectiveMax = GetUnitPower("player", POWERTYPE_STAMINA)
	playerElem["stamina"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_HEALTH)
	playerElem["health"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_MAGICKA)
	playerElem["magicka"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_POWER)
	playerElem["power"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_WEREWOLF)
	playerElem["werewolf"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_FERVOR)
	playerElem["fervor"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_COMBO)
	playerElem["combo"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_CHARGES)
	playerElem["charges"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_MOUNT_STAMINA)
	playerElem["mntStamina"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_MOUNT_SPEED)
	playerElem["mntSpeed"] = max
	current, max, effectiveMax = GetUnitPower("player", POWERTYPE_MOUNT_CAPACITY)
	playerElem["mntCapacity"] = max
	--
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataRiding( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	local inventoryBonus, maxInventoryBonus, staminaBonus, maxStaminaBonus, speedBonus, maxSpeedBonus =   GetRidingStats()
	playerElem.inventory = inventoryBonus
	playerElem.stamina   = staminaBonus
	playerElem.speed     = speedBonus
	local canTrainRiding = false
	if(speedBonus < maxSpeedBonus)then
		canTrainRiding = true
	elseif (staminaBonus < maxStaminaBonus) then
		canTrainRiding = true
	elseif(inventoryBonus < maxInventoryBonus) then
		canTrainRiding = true
	end
	playerElem.cantrain = canTrainRiding   
	local timeMs, totalDurationMs = GetTimeUntilCanBeTrained()
	playerElem.timeMs          = timeMs
	playerElem.totalDurationMs = totalDurationMs
	playerElem.timeDataTaken   = GetTimeStamp()--secconds
	if(timeMs<1)then
		playerElem.trainingReadyAt  = 0
	else
		--EchoESOADatastore.debugMsg("timeMs="..tostring(timeMs) )
		local expiresAt = GetTimeStamp() + ( timeMs/1000 )
		--local expiresAt = GetTimeStamp() + timeMs
		playerElem.trainingReadyAt  = expiresAt
	end
end
	
------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataSkillpoints( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	playerElem.skillpoints     = GetAvailableSkillPoints() 
	playerElem.skillpointsfree = GetAvailableSkillPoints()
	--playerElem.skillpointstotal = GetAvailableSkillPoints() 
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataAchieve( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--  
	local earnedAchievePts = GetEarnedAchievementPoints()
	playerElem.earned = earnedAchievePts
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataCurrency( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	local currType = {CURT_ALLIANCE_POINTS, CURT_CHAOTIC_CREATIA,CURT_CROWNS,CURT_CROWN_GEMS,CURT_MONEY,CURT_NONE,CURT_STYLE_STONES,CURT_TELVAR_STONES,CURT_WRIT_VOUCHERS}
	local cLoc = CURRENCY_LOCATION_CHARACTER
	for ctIdx = 1, #currType do
		local cType = currType[ctIdx]
		local amount = GetCurrencyAmount( cType, cLoc )
		local IS_PLURAL = false
		if(amount and amount>1) then IS_PLURAL = true end
		local currencyName = GetCurrencyName(cType, IS_PLURAL, false)
		playerElem[cType] = {}
		playerElem[cType].currencyName = currencyName
		playerElem[cType].amount       = amount
	end
end

------------------------------
-- INT TODO
function EchoESOADatastore.saveCurrentPlayerDataPVP( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataAVA( playerKey, sectionElem )
	if(sectionElem[playerKey]==nil) then
		sectionElem[playerKey] = {}
	end
	local playerElem = sectionElem[playerKey]
	--
	--PVP Ava Campaign Cyrodil PVP (TODO) --  
	playerElem.inCampaign = IsInCampaign()

	local currentCampaignId  = GetCurrentCampaignId()--this not the best one?
	local guestCampaignId    = GetGuestCampaignId()
	local assignedCampaignId = GetAssignedCampaignId()
	local isInCampaign       = currentCampaignId ~= 0
	if(not isInCampaign) then
		isInCampaign       = assignedCampaignId ~= 0
	end
	--GetPreferredCampaign()  ??
 
	playerElem.guestCampaignId    = guestCampaignId
	playerElem.currentCampaignId  = currentCampaignId
	playerElem.assignedCampaignId = assignedCampaignId
  
	--
	playerElem.guestCampaignName    = GetCampaignName(guestCampaignId)
	playerElem.currentCampaignName  = GetCampaignName(currentCampaignId)
	playerElem.assignedCampaignName = GetCampaignName(assignedCampaignId)
	--playerElem.assignedcampaignname = playerElem.assignedCampaignName

	playerElem.isInCampaign         = isInCampaign
	playerElem.unitAlliance         = pAlliance
	playerElem.allianceName         = GetAllianceName(pAlliance)
  
	local avaRank = GetUnitAvARank("player")
	local unitAvARankPoints = GetUnitAvARankPoints("player") 
	playerElem.unitAvARank       = avaRank  
	playerElem.unitAvARankPoints = unitAvARankPoints
	-- number subRankStartsAt, number nextSubRankAt, number rankStartsAt, number nextRankAt 
	local subRankStartsAt, nextSubRankAt, rankStartsAt, nextRankAt = GetAvARankProgress(unitAvARankPoints)
	playerElem.AvaSubRankStart   = subRankStartsAt
	playerElem.AvaNextSubRank    = nextSubRankAt
	playerElem.AvaRankStarts     = rankStartsAt
	playerElem.AvaNextRank       = nextRankAt

	local avaRankName = GetAvARankName( GetUnitGender("player"), avaRank )
	playerElem.avaRankName = avaRankName
  
	--Returns: number earnedTier, number nextTierProgress, number nextTierTotal
	local readyState = LEADERBOARD_DATA_RESPONSE_PENDING
	readyState = QueryCampaignLeaderboardData(ALLIANCE_NONE) --pAlliance)
	if(readyState == LEADERBOARD_DATA_READY) then
		local earnedTier, nextTierProgress, nextTierTotal = GetPlayerCampaignRewardTierInfo(assignedCampaignId)
		EchoESOADatastore.debugMsg( 
			"earnedTier: '",         earnedTier,
			"' nextTierProgress: '", nextTierProgress,
			"' nextTierTotal: '",    nextTierTotal,"'" )
		playerElem.AssignedCampaignLastloaded = GetTimeStamp()
		playerElem.AssignedCampaignRewardEarnedTier       = tonumber(earnedTier)
		playerElem.AssignedCampaignRewardNextProgressTier = tonumber(nextTierProgress)
		playerElem.AssignedCampaignRewardNextTotalTier    = tonumber(nextTierTotal)
		--playerElem.currentCampaignRewardEarnedTier = earnedTier  
		earnedTier, nextTierProgress, nextTierTotal = GetPlayerCampaignRewardTierInfo(guestCampaignId)
		playerElem.guestCampaignRewardEarnedTier = tonumber(earnedTier)
		if(EchoESOADatastore.view.alliancenotsaved) then
			EchoESOADatastore.view.alliancenotsaved = false
			if(loadtype==nil or loadtype==EchoESOADatastore.manualload or loadtype==EchoESOADatastore.startupload ) then
				--if( EchoESOADatastore.CtrlIsShowPvpWarnings() ) then
					EchoESOADatastore.outputMsg( GetString(ESOA_ALLIANCE_READY) )  
				--end
			end
		end
	else
		-- show message if, alliance data wasn't saved before, and was a manual or startup call
		if(EchoESOADatastore.view.alliancenotsaved==nil or EchoESOADatastore.view.alliancenotsaved==true) then
			if(loadtype==nil or loadtype==EchoESOADatastore.manualload or loadtype==EchoESOADatastore.startupload ) then
				--if( EchoESOADatastore.CtrlIsShowPvpWarnings() ) then
					EchoESOADatastore.outputMsg( GetString(ESOA_ALLIANCE_NOTREADY) )
				--end
			end
		end
		EchoESOADatastore.view.alliancenotsaved = true
	end
	--
	-- EchoESOADatastore
	--
	local dName = GetDisplayName()
	--
	if(EchoESOADatastore.svESOADataAW[dName]==nil) then
		EchoESOADatastore.svESOADataAW[dName] = {}
	end
	if(EchoESOADatastore.svESOADataAW[dName].ava==nil) then
		EchoESOADatastore.svESOADataAW[dName].ava = {}
		EchoESOADatastore.svESOADataAW[dName].ava.campaigns = {}
	end
	local accountAvaElem = EchoESOADatastore.svESOADataAW[dName].ava
	--
	local avaAEnd = GetSecondsUntilCampaignEnd(assignedCampaignId)
	EchoESOADatastore.debugMsg("avaAEnd: '", avaAEnd, "'")
	if(avaAEnd~=nil and avaAEnd<0) then
		EchoESOADatastore.debugMsg("avaAEnded???: '", avaAEnd, "'")  
	elseif(avaAEnd~=nil and avaAEnd~=0) then
		playerElem.AssignedCampaignEndsSeconds = GetSecondsUntilCampaignEnd(assignedCampaignId)
		local AC_expiresAt = GetTimeStamp() + ( playerElem.AssignedCampaignEndsSeconds )
		playerElem.AssignedCampaignEndsAt = AC_expiresAt
		accountAvaElem.campaigns[assignedCampaignId] = {}
		accountAvaElem.campaigns[assignedCampaignId].campaignEndsAt = AC_expiresAt
		accountAvaElem.campaigns[assignedCampaignId].campaignId     = assignedCampaignId
		EchoESOADatastore.debugMsg("avaAEnd saved to cache '", AC_expiresAt, "'")
	else
		if( accountAvaElem~=nil and accountAvaElem.campaigns ~= nil and  accountAvaElem.campaigns[assignedCampaignId]~=nil and accountAvaElem.campaigns[assignedCampaignId].campaignEndsAt~=nil) then
			playerElem.AssignedCampaignEndsAt = accountAvaElem.campaigns[assignedCampaignId].campaignEndsAt
			EchoESOADatastore.debugMsg("avaAEnd loaded from cache '", playerElem.AssignedCampaignEndsAt, "'")
		end
	end
	--
	playerElem.assignedcampaignendsat = playerElem.AssignedCampaignEndsAt
	--GetLargeAvARankIcon(rank))
	--GetAllianceColor(alliance):UnpackRGBA())

	if not (isInCampaign or assignedCampaignId) then
		--no campaign
	else
		--TODO
		--local campaignName = GetCampaignName(campaignId)    
	end
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataInfamy( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--infamy = GetInfamy()
	--heat, bounty GetPlayerInfamyData()
	--infamyThresholdType = getInfamyLevel( infamy )
	-- INFMAY_THRESHHOLD_DISREPUTABLE, FUGITIVE, NOTOFIOUS, UPSTANDING  
	local infamy = GetInfamy()
	local bounty = GetBounty()
	EchoESOADatastore.debugMsg("infamy="..tostring(infamy) )	
	local fullBountyPayoffAmount    = GetFullBountyPayoffAmount()
	local reducedBountyPayoffAmount = GetReducedBountyPayoffAmount()
	local infamyLevel     = GetInfamyLevel(infamy)
	local infamyLevelText = ElderScrollsOfAlts:getInfamyLevelText(infamyLevel)

	playerElem.displayText = infamyLevelText
	playerElem.infamy = infamy
	playerElem.bounty = bounty
	playerElem.fullBounty    = fullBountyPayoffAmount
	playerElem.reducedBounty = reducedBountyPayoffAmount
	
	--** _Returns:_ *integer* _totalLaunders_, *integer* _laundersUsed_, *integer* _resetTimeSeconds_
	local totalLaunders, laundersUsed, resetTimeSeconds = GetFenceLaunderTransactionInfo()
	playerElem.LaundersUsed = laundersUsed
	playerElem.LaundersTotal = totalLaunders	
	--
	--** _Returns:_ *integer* _totalSells_, *integer* _sellsUsed_, *integer* _resetTimeSeconds_
	local totalSells, sellsUsed, resetTimeSeconds2 = GetFenceSellTransactionInfo()
	playerElem.SellsUsed = sellsUsed
	playerElem.SellsTotal = totalSells

	local sBountyDecayZero = GetSecondsUntilBountyDecaysToZero()
	local sHeatDecayZero   = GetSecondsUntilHeatDecaysToZero()
	local now = GetTimeStamp()

	--local timeTillReady = GetTimeStamp() + sBountyDecayZero
	playerElem.bountytozero = now + sBountyDecayZero
	playerElem.heattozero   = now + sHeatDecayZero
	playerElem.LaunderReset = now + resetTimeSeconds2

	--local thresholdType = getInfamyLevel( infamy )
	--local heat, bounty = GetPlayerInfamyData()
	--playerElem.payoffAmount  = payoffAmount  
	--playerElem.heat   = heat
	--playerElem.bounty = bounty  
	--playerElem.thresholdType = thresholdType  
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataLocation( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	----Section: Location section  
	local subzoneNamePL = zo_strformat("<<1>>", GetPlayerActiveSubzoneName() )
	local zoneNamePL    = zo_strformat("<<1>>", GetPlayerActiveZoneName() )
	local zoneIndex     = GetUnitZoneIndex("player")
	local zoneId, worldX, worldY, worldZ   = GetUnitWorldPosition("player")  
	--local zDescription  =  GetZoneDescription(zoneIndex)
	--local zoneId        = GetZoneId(zoneIndex)
	playerElem.subzoneName = subzoneNamePL
	playerElem.zoneName    = zoneNamePL
	playerElem.zoneId      = zoneId
	--
	playerElem.lastlogin= EchoESOADatastore.view.pNow
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataResearch( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	playerElem.now = GetTimeStamp()
	EchoESOADatastore:saveCurrentPlayerDataResearchData(CRAFTING_TYPE_BLACKSMITHING,   "blacksmithing", playerElem)
	EchoESOADatastore:saveCurrentPlayerDataResearchData(CRAFTING_TYPE_CLOTHIER,        "clothier",      playerElem)
	EchoESOADatastore:saveCurrentPlayerDataResearchData(CRAFTING_TYPE_WOODWORKING,     "woodworking",    playerElem)
	EchoESOADatastore:saveCurrentPlayerDataResearchData(CRAFTING_TYPE_JEWELRYCRAFTING, "jewelcrafting", playerElem)
end

--collectResearchData
function EchoESOADatastore:saveCurrentPlayerDataResearchData(tradeSkillType, keyProfName, dataResearchElem)
	dataResearchElem[keyProfName] = {}
	local researchMaxSimulSlots = GetMaxSimultaneousSmithingResearch(tradeSkillType)
	local researchNumlines      = GetNumSmithingResearchLines(tradeSkillType)
	dataResearchElem[keyProfName].ongoing = {}
	dataResearchElem[keyProfName].lines = {}
	dataResearchElem[keyProfName].researchNumlinesDone = 0
	dataResearchElem[keyProfName].researchNumlines      = researchNumlines
	dataResearchElem[keyProfName].researchMS            = researchMaxSimulSlots
	dataResearchElem[keyProfName].researchMaxSimulSlots = researchMaxSimulSlots
	dataResearchElem[keyProfName].researchNumlines      = researchNumlines
	--
	for researchLineIndex = 1, researchNumlines do
		local name, icon, numTraits, timeRequiredForNextResearchSecs = GetSmithingResearchLineInfo(tradeSkillType, researchLineIndex)
		--
		dataResearchElem[keyProfName].lines[name] = {}
		dataResearchElem[keyProfName].lines[name].name           = name
		dataResearchElem[keyProfName].lines[name].numTraits      = numTraits
		dataResearchElem[keyProfName].lines[name].numTraitsKnown = 0
		dataResearchElem[keyProfName].lines[name].researchLineIndex = researchLineIndex    
		dataResearchElem[keyProfName].lines[name].timeRequiredForNextResearchSecs = timeRequiredForNextResearchSecs    
		-- 
		for traitIndex = 1, numTraits do
		  --local traitType, traitDescription, known = GetSmithingResearchLineTraitInfo(tradeSkillType, researchLineIndex, traitIndex)
		  local durationSecs, timeRemainingSecs    = GetSmithingResearchLineTraitTimes(tradeSkillType, researchLineIndex, traitIndex)
		  local traitType, traitDescription, known = GetSmithingResearchLineTraitInfo(tradeSkillType,  researchLineIndex, traitIndex)
		  if(durationSecs~=nil) then
			local timeTillReady = GetTimeStamp() + timeRemainingSecs
			dataResearchElem[keyProfName].ongoing[name] = {}
			dataResearchElem[keyProfName].ongoing[name].name              = name
			dataResearchElem[keyProfName].ongoing[name].durationSecs      = durationSecs
			dataResearchElem[keyProfName].ongoing[name].timeRemainingSecs = timeRemainingSecs
			dataResearchElem[keyProfName].ongoing[name].timeTillReady     = timeTillReady
			dataResearchElem[keyProfName].ongoing[name].traitIndex        = traitIndex
			dataResearchElem[keyProfName].ongoing[name].researchLineIndex = researchLineIndex
			dataResearchElem[keyProfName].ongoing[name].traitType         = traitType
			dataResearchElem[keyProfName].ongoing[name].traitDescription  = traitDescription
			dataResearchElem[keyProfName].ongoing[name].known             = known
		  end
		  if(known) then
			dataResearchElem[keyProfName].lines[name].numTraitsKnown = dataResearchElem[keyProfName].lines[name].numTraitsKnown + 1
		  end
		end --for trait
		if( numTraits == dataResearchElem[keyProfName].lines[name].numTraitsKnown ) then
		  dataResearchElem[keyProfName].researchNumlinesDone = dataResearchElem[keyProfName].researchNumlinesDone + 1
		end
	end -- research
  --[[ TODO: get num traints known?
  for i = 1, GetMaxTraits() do
    local known, name = GetItemLinkReagentTraitInfo(itemLink, i)
    if known then
      d(zo_strformat("Trait <<1>> is known; it's <<2>>.", i, name))
    end
     boolean known = IsSmithingTraitKnownForResult(number patternIndex, number materialIndex, number materialQuantity, number itemStyleId, number traitIndex)
  end
  number numTraitItems = GetNumSmithingTraitItems()
  Returns: number:nilable ItemTraitType traitType, string itemName, textureName icon, number sellPrice, boolean meetsUsageRequirement, number itemStyleId, number ItemQuality quality
  GetSmithingTraitItemInfo(number traitItemIndex)
Returns: string link = GetSmithingTraitItemLink(number traitItemIndex, number LinkStyle linkStyle)
  --]]
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataBags( playerKey, sectionElem )
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	-- Bags
	local bagSize = GetBagSize(BAG_BACKPACK) 
	local bagUsed = GetNumBagUsedSlots(BAG_BACKPACK)
	playerElem.backpackSize = bagSize
	playerElem.backpackUsed = bagUsed
	playerElem.backpackFree = tonumber( bagSize-bagUsed )
	--EchoESOADatastore.outputMsg("bags: bagSize=",bagSize, " bagUsed=",bagUsed, " free=",playerElem.backpackFree )
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataBank( playerKey, sectionElem )
	if(sectionElem==nil) then
		sectionElem = {}
	end
	-- Bank
	local bagSizeB = GetBagSize(BAG_BANK) 
	local bagUsedB = GetNumBagUsedSlots(BAG_BANK)
	sectionElem.bankSize = bagSizeB
	sectionElem.bankUsed = bagUsedB
	sectionElem.bankFree = tonumber( bagSizeB-bagUsedB )
	--bank?
	--if(EchoESOADatastore.svESOADataAW.data = nil ) then
	--	EchoESOADatastore.svESOADataAW.data = {}
	--end
	--EchoESOADatastore.svESOADataAW.data.server[pServer] = {}
	--EchoESOADatastore.svESOADataAW.data.server[pServer].bankSize = bagSizeB
	--EchoESOADatastore.svESOADataAW.data.server[pServer].bankUsed = bagUsedB
	--EchoESOADatastore.svESOADataAW.data.server[pServer].bankFree = tonumber( bagSizeB-bagUsedB )
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataBuffs( playerKey, sectionElem )
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	local numBuffs = GetNumBuffs("player") 
	for buffIndex = 1, numBuffs do
	--string buffName, number timeStarted, number timeEnding, number buffSlot, number stackCount, textureName iconFilename, string buffType, number BuffEffectType effectType, number AbilityType abilityType, number StatusEffectType statusEffectType, number abilityId, boolean canClickOff, boolean castByPlayer
	local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("player", buffIndex)
	playerElem[buffName] = {}
	playerElem[buffName].timeStarted  = timeStarted 
	playerElem[buffName].timeEnding   = timeEnding
	playerElem[buffName].abilityId    = abilityId
	playerElem[buffName].iconFilename = iconFilename
	local duration = timeEnding - timeStarted
	playerElem[buffName].duration     = duration

	if(duration > 0) then
		local timeLeftS = (timeEnding) - GetFrameTimeSeconds() -- time end - time in frame is time left
		--data:SetCooldown(timeLeft, duration * 1000.0)
		playerElem[buffName].expiresAt = GetTimeStamp() + (timeLeftS)
	else
	  playerElem[buffName].expiresAt = 0
	end
	--[[TODO TESTING
	if(TODO[playerKey].buffs[buffName].expiresAt~=0) then
	  --Time in seconds left till expires
	  local timeDiff = GetDiffBetweenTimeStamps( TODO[playerKey].buffs[buffName].expiresAt, GetTimeStamp() )
	  EchoESOADatastore.debugMsg("Buff Data: name: '".. buffName .. "' expires="..tostring(TODO[playerKey].buffs[buffName].expiresAt) .. " timeDiff=".. tostring(timeDiff) )
	end--]]
	--TODO.players[playerKey].buffs[buffName].expiresAt = GetTimeStamp() + ( timeEnding-timeStarted )
	--[[
	if(buffName=="Major Protection")then
	  d("Has Major Protection!****")
	elseif(buffName=="Minor Protection")then
	  d("Has Minor Protection!****")
	else
	  d("Has buff "..tostring(buffName))
	end
	--]]
	end--for buffs
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataResearchtraits( playerKey, sectionElem)
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	if(playerElem == nil) then
		playerElem.unknown         = {}
		playerElem.blacksmithing   = {}
		playerElem.clother         = {}
		playerElem.woodworking     = {}
		playerElem.jewelrycrafting = {}
	end
	local baseRTElem = playerElem
	for patternIndex = 1, GetNumSmithingPatterns() do
		local patternName, baseName, _, numMaterials, numTraitsRequired, numTraitsKnown, resultingItemFilterType = GetSmithingPatternInfo(patternIndex)
		local craftingType = GetCraftingInteractionType()-- ONLY valid when crafting table OPEN!
		EchoESOADatastore.debugMsg("DataSaveLivePlayer: Trait: patternName: ", patternName , " numMaterials: " , numMaterials, " numTraitsKnown: ", numTraitsKnown, " TYPE=", craftingType )  
		EchoESOADatastore.debugMsg("DataSaveLivePlayer: TYPElIST: BLACKSMITHING: ", CRAFTING_TYPE_BLACKSMITHING , " CLOTHIER: " , CRAFTING_TYPE_CLOTHIER, " WOODWORKING: ", CRAFTING_TYPE_WOODWORKING)
		local baseTTElem = baseRTElem.unknown
		if craftingType == CRAFTING_TYPE_BLACKSMITHING then
			baseTTElem = baseRTElem.blacksmithing
		elseif craftingType == CRAFTING_TYPE_CLOTHIER then
			baseTTElem = baseRTElem.clother
		elseif craftingType == CRAFTING_TYPE_WOODWORKING then
			baseTTElem = baseRTElem.woodworking
		elseif craftingType == CRAFTING_TYPE_JEWELRYCRAFTING then
			baseTTElem = baseRTElem.jewelrycrafting
		end
		if(baseTTElem==nil) then
			baseTTElem = {}
		end
		if(baseTTElem[patternName]==nil) then
			baseTTElem[patternName] = {}
		end
		baseTTElem[patternName].numTraitsKnown = numTraitsKnown    
	end
	--Test TRAITS
end

------------------------------
-- INT
function EchoESOADatastore.saveCurrentPlayerDataCompanions( playerKey, sectionElem)
	if(sectionElem[playerKey] == nil ) then
		sectionElem[playerKey] = {}
	end
	local playerElem = sectionElem[playerKey]
	--
	if(playerElem == nil) then
		playerElem = {}
	end
	--COMPANIONS
	-- Can't get list of companions? Have to use only active one/
	if( HasActiveCompanion() ) then
		local defId = GetActiveCompanionDefId()
		EchoESOADatastore.debugMsg("saveCompanionData: defId=",defId)
	end
	-- Do this in events
	--COMPANION END
end

------------------------------
------------------------------

------------------------------
-- INT (part 2)
function EchoESOADatastore:SaveDataSkillData(skillType,baseElem,outputUndiscovered,playerRanksElem)
	EchoESOADatastore.debugMsg("SaveDataSkillData: skillType=",skillType, " outputUndiscovered=",outputUndiscovered)
	if skillType == nil then
	  EchoESOADatastore.outputMsg("SaveDataSkillData: WARNING: skillType is NIL")
	  return
	end
	--	
	local numSkillLines = GetNumSkillLines(skillType)
	for ii = 1, numSkillLines do
		local name, rank, discovered, skillLineId, advised, unlockText = GetSkillLineInfo(skillType,ii)
		--name, number rank, boolean discovered, number skillLineId, boolean advised, unlockText
		if name == nil then
			name = ii;
		end
		local skip = false
		if name:find("Vengeance ", 1, true) == 1 and skillType == SKILL_TYPE_CLASS then
			skip = true
		end
		if not skip and ( discovered or outputUndiscovered) then
			--EchoESOADatastore.outputMsg("loadPlayerDataPart: name=",name," rank=",rank, " discovered=",discovered)			
			--EchoESOADatastore.debugMsg("loadPlayerDataPart: unlockText="..unlockText..".")
			baseElem[name]	= {}
			local baseElemTable = baseElem[name]
			local numAbilities = GetNumSkillAbilities(skillType, ii)
			baseElemTable.name = name
			baseElemTable.idx  = ii
			baseElemTable.rank = rank
			baseElemTable.numAbilities = numAbilities
			baseElemTable.skillLineId  = skillLineId
			if(playerRanksElem~=nil and name~=nil) then
				playerRanksElem[name] = rank
			else
				EchoESOADatastore.outputMsg("Error writing to pre. ii="..tostring(ii).. "x=" .. tostring(name) );
			end
			--ie: SaveDataSkillData:[Assault] lastRankXP:758000 nextRankXP:1158000 currentXP:758978
			local lastRankXP, nextRankXP, currentXP  = GetSkillLineXPInfo( skillType, ii )
			baseElemTable.lastRankXP = lastRankXP
			baseElemTable.nextRankXP = nextRankXP
			baseElemTable.currentXP  = currentXP
			EchoESOADatastore.debugMsg("SaveDataSkillData:[",name,"] lastRankXP:",lastRankXP, " nextRankXP:",nextRankXP, " currentXP:",currentXP)

			--** _Returns:_ *luaindex* _rank_, *bool* _isAdvised_, *bool* _isActive_, *bool* _isDiscovered_, *bool* _isAccountSkill_, *bool* _isInTraining_, *bool* _isClassMastery_
			local rank2, isAdvised2, isActive2, isDiscovered2, isAccountSkill2, isInTraining2, isClassMastery2
			= GetSkillLineDynamicInfo(skillType,ii)
			--EchoESOADatastore.outputMsg("loadPlayerDataPart: name=",name," isActive2=",isActive2, " isDiscovered2=",isDiscovered2," isAccountSkill=",isAccountSkill2, " isClassMastery=",isClassMastery2, " " )
			baseElemTable.isAccountSkill = isAccountSkill2
			baseElemTable.isClassMastery = isClassMastery2

			--EchoESOADatastore.loadPlayerDataPartDetails(skillType,skillLineId,ii,name,pName)
			--string name, textureName texture, number earnedRank, boolean passive, boolean ultimate, boolean purchased, number:nilable progressionIndex, number:nilable rankIndex 
			--GetSkillAbilityInfo(number SkillType skillType, number skillIndex, number abilityIndex)
			baseElemTable.abilities = {}
			local baseAbilityElem = baseElemTable.abilities
			for abilityIndex = 1, numAbilities do
				local ABname, ABtextureName, ABearnedRank, ABpassive, ABultimate, ABpurchased, ABprogressionIndex, ABrankIndex =
				GetSkillAbilityInfo(skillType, ii, abilityIndex)
				baseAbilityElem[ABname] = {}
				baseAbilityElem[ABname].name        = ABname
				baseAbilityElem[ABname].textureName = ABtextureName
				baseAbilityElem[ABname].earnedRank  = ABearnedRank
				baseAbilityElem[ABname].passive     = ABpassive
				baseAbilityElem[ABname].ultimate    = ABultimate
				baseAbilityElem[ABname].purchased   = ABpurchased
				baseAbilityElem[ABname].progressionIndex = ABprogressionIndex
				baseAbilityElem[ABname].rankIndex   = ABrankIndex
			end
			--
		end      
	end
end

------------------------------
-- INT (part 2)
function EchoESOADatastore.SaveDataPlayerTradeDetails(parentName, infoElem, subskillElem, skillType, ii, numAbilities )
	--EchoESOADatastore.debugMsg("parentName='",parentName,"'")
	--EchoESOADatastore.debugMsg("parentTableElem='",parentTableElem,"'")
	--parentTableElem.skills[parentName]	= {}
	--local selElemSubTable = subskillElem --parentTableElem.skills[parentName]
	local skillIndex = ii
	infoElem.sunk     = 0
	infoElem.sinkmax  = 0
	infoElem.sunk2    = 0
	infoElem.sinkmax2 = 0
	for aj = 1, numAbilities do
		local name, icon, earnedRank, passive, ultimate, purchased, progressionIndex = GetSkillAbilityInfo(skillType, ii, aj)
		--EchoESOADatastore.debugMsg("TradeSkill Ability: name="..name.. " purchased="..tostring(purchased))
		local currentUpgradeLevel, maxUpgradeLevel = GetSkillAbilityUpgradeInfo(skillType, skillIndex, aj)
		--name, textureName texture, number:nilable earnedRank
		local _, _, nextUpgradeEarnedRank = GetSkillAbilityNextUpgradeInfo(skillType, skillIndex, aj)
		local plainName = zo_strformat(SI_ABILITY_NAME, name)
		name = ZO_Skills_GenerateAbilityName(SI_ABILITY_NAME_AND_UPGRADE_LEVELS, name, currentUpgradeLevel, maxUpgradeLevel, progressionIndex)
		--local name, rank, discovered, skillLineId, advised, unlockText = GetSkillLineInfo(skillType,ii)
		--if not (currentUpgradeLevel and maxUpgradeLevel) and progressionIndex then
		--    self.displayedAbilityProgressions[progressionIndex] = true
		--end
		--local isActive = (not passive and not ultimate)
		--local isUltimate = (not passive and ultimate)
		--EchoESOADatastore.debugMsg("TradeSkill Ability: passive="..tostring(passive))
		
		if purchased then
			subskillElem[plainName] = {}
			local selL = subskillElem[plainName]
			selL.plainName  = plainName
			selL.name       = name
			selL.earnedRank = earnedRank
			selL.currentUpgradeLevel   = currentUpgradeLevel
			selL.maxUpgradeLevel       = maxUpgradeLevel
			selL.nextUpgradeEarnedRank = nextUpgradeEarnedRank
			local match1 = EchoESOADatastore:matchStringList(plainName, EchoESOADatastore.view.matchNameList1)
			if match1 then
				infoElem.sunk    = infoElem.sunk    + (currentUpgradeLevel - 1)
				infoElem.sinkmax = infoElem.sinkmax + (maxUpgradeLevel - 1)
				--selElemSubTable.sunk    = selElemSubTable.sunk    + (currentUpgradeLevel - 1)
				--selElemSubTable.sinkmax = selElemSubTable.sinkmax + (maxUpgradeLevel - 1)
				--infoElem.sunk     = selElemSubTable.sunk
				--infoElem.sinkmax  = selElemSubTable.sinkmax
			end
			local match2 = EchoESOADatastore:matchStringList(plainName, EchoESOADatastore.view.matchNameList2)
			if match2 then
				infoElem.sunk2    = infoElem.sunk2    + (currentUpgradeLevel - 1)
				infoElem.sinkmax2 = infoElem.sinkmax2 + (maxUpgradeLevel - 1)
				--selElemSubTable.sunk2    = selElemSubTable.sunk2    + (currentUpgradeLevel - 1)
				--selElemSubTable.sinkmax2 = selElemSubTable.sinkmax2 + (maxUpgradeLevel - 1)
				--infoElem.sunk2     = selElemSubTable.sunk2
				--infoElem.sinkmax2  = selElemSubTable.sinkmax2
				--EchoESOADatastore.debugMsg("loadPlayerTradeDetails: plainName="..plainName.." sunk2="..selElemSubTable.sunk2)
			end
		end--purchased
	end --for
end

------------------------------
-- INT - Only use for CURRENT Server
function EchoESOADatastore.saveCharcterCustomData(characterLineKey, keyName, elementData)
	EchoESOADatastore.debugMsg("SaveCustomData: character=",tostring(characterLineKey)," keyName=",tostring(keyName)," as '", tostring(elementData),"'")
	EchoESOADatastore.checkNullData(characterLineKey)
	--
	if( EchoESOADatastore.svCharDataAW.custom == nil ) then
		EchoESOADatastore.svCharDataAW.custom = {}
	end
	if( EchoESOADatastore.svCharDataAW.custom[characterLineKey] == nil ) then
		EchoESOADatastore.svCharDataAW.custom[characterLineKey] = {}
	end
	EchoESOADatastore.svCharDataAW.custom[characterLineKey][keyName] = elementData
	--EchoESOADatastore.debugMsg("SaveCustomData: player=",characterLineKey," keyName=",keyName," as ", elementData)
	--
	--[[Special condition
	if( keyName == "category" )	then
		local dName = GetDisplayName()
		EchoESOADatastore.svListDataAW[dName].players[characterLineKey].category = elementData
	end
	]]
end

------------------------------
-- INT 20250517
function EchoESOADatastore.getCharcterCustomData(characterLineKey, keyName)
	EchoESOADatastore.debugMsg("GetCustomData: character=",tostring(characterLineKey)," keyName=",tostring(keyName),"'")
	EchoESOADatastore.checkNullData(characterLineKey)
	--
	if( EchoESOADatastore.svCharDataAW.custom == nil ) then
		EchoESOADatastore.svCharDataAW.custom = {}
	end
	if( EchoESOADatastore.svCharDataAW.custom[characterLineKey] == nil ) then
		EchoESOADatastore.svCharDataAW.custom[characterLineKey] = {}
	end
	return EchoESOADatastore.svCharDataAW.custom[characterLineKey][keyName]
end


------------------------------
-- save
function EchoESOADatastore.saveCurrentPlayerDataCPInt()
	EchoESOADatastore.saveCurrentPlayerDataChampionPoints( EchoESOADatastore.getCurrentCharacterKey() , EchoESOADatastore.svCharDataAW.sections.championpoints )
end
	
------------------------------
-- INT TODO
function EchoESOADatastore.getCurrentCharacterKey()
	-- Initial Data	
	local dName 	= GetDisplayName()
	local pName     = GetUnitName("player")
	local rName     = GetRawUnitName("player")   
	local pID       = GetCurrentCharacterId()
	local pServer   = GetWorldName()
	local playerKey = pID.."_".. pServer:gsub(" ","_")
	return playerKey
end

------------------------------
-- INT TODO
-- Saves all Player data
function EchoESOADatastore.saveCurrentPlayerDataChampionPoints( playerKey, sectionElem )
	EchoESOADatastore.debugMsg("CollectCP: called")
	if(sectionElem[playerKey] == nil ) then
		sectionElem[playerKey] = {}
	end
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
    playerElem.championpointsactive = {}
    --
    local CP = CHAMPION_PERKS
    local championBar = CHAMPION_PERKS:GetChampionBar() 
    local CPData = CHAMPION_DATA_MANAGER
    
    local start, nd = GetAssignableChampionBarStartAndEndSlots() -- 1 and 12.
	--d("start:"..tostring(start).." nd:"..tostring(nd) )
    for i=start, nd do -- loop all (12) slots.
		local starId  = GetSlotBoundId(i, HOTBAR_CATEGORY_CHAMPION)
		local req     = GetRequiredChampionDisciplineIdForSlot(i, HOTBAR_CATEGORY_CHAMPION)
		local disType = GetChampionDisciplineType(req)
		--
		if starId ~= 0 then
			local pointsSpent = GetNumPointsSpentOnChampionSkill(starId)
			local name = GetChampionSkillName(starId)
			playerElem.championpointsactive[i] = {}
			playerElem.championpointsactive[i].id = starId
			playerElem.championpointsactive[i].name = name
			playerElem.championpointsactive[i].disciplineid = req
			playerElem.championpointsactive[i].disciplinetype = disType
			playerElem.championpointsactive[i].numspentpoints = pointsSpent
		end
    end
    --
    playerElem.championpoints = {}
    local numDisciplines = GetNumChampionDisciplines()
    --d("numDisciplines: " .. tostring(numDisciplines) )
    for disciplineIndex = 1, numDisciplines do
		playerElem.championpoints[disciplineIndex] = {}
		playerElem.championpoints[disciplineIndex].name = GetChampionDisciplineName(disciplineIndex)
		--
		for championSkillIndex = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
			local championSkillId = GetChampionSkillId(disciplineIndex, championSkillIndex)
			--local numPendingPoints =  GetNumPendingChampionPoints(disciplineIndex, championSkillIndex)
			local ptsspent  = GetNumPointsSpentOnChampionSkill(championSkillId)
			if(ptsspent>0) then
				local championSkillType = GetChampionSkillType(championSkillId)
				local isSlottable       = ElderScrollsOfAlts:CheckIfCpTypeIsSlottable( championSkillType )
				if(isSlottable) then
					local name      = GetChampionSkillName(championSkillId)
					local abilityId = GetChampionAbilityId(championSkillId)
					playerElem.championpoints[disciplineIndex][championSkillId] = {}
					--playerElem.championpoints[disciplineIndex][championSkillId].pts = numPendingPoints
					playerElem.championpoints[disciplineIndex][championSkillId].name      = name
					playerElem.championpoints[disciplineIndex][championSkillId].ptsspent  = ptsspent
					playerElem.championpoints[disciplineIndex][championSkillId].abilityId = abilityId
				end
			end--spent points
		end
    end
	EchoESOADatastore.debugMsg("CollectCP: done")
end
--CollectCP()

------------------------------
-- INT  TODO
function EchoESOADatastore.saveCurrentPlayerDataEquipment( playerKey, sectionElem )
	if(sectionElem[playerKey] == nil ) then
		sectionElem[playerKey] = {}
	end
	sectionElem[playerKey] = {}
	local playerElem = sectionElem[playerKey]
	--
	playerElem.items = {}
    playerElem.slots = {}
	local elemH = playerElem.slots
	for slotId = 0, GetBagSize(BAG_WORN) do    
		local itemName = GetItemName(BAG_WORN, slotId)
		--quality is numeric
		local icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, quality = GetItemInfo(BAG_WORN, slotId)
		local itemId = GetItemInstanceId(BAG_WORN, slotId)
		local itemLink = GetItemLink(BAG_WORN, slotId)--, number LinkStyle linkStyle) 
		local itemLevel = GetItemLevel(BAG_WORN, slotId)
		if( equipType ~= nil and equipType > EQUIP_TYPE_MIN_VALUE ) then
			--TODO check itemname not nil, and EquipType > 0
			elemH[slotId] = {}
			elemH[slotId].itemId   = itemId
			elemH[slotId].itemName = itemName
			elemH[slotId].itemLink = itemLink
			elemH[slotId].icon = icon
			elemH[slotId].quality = quality
			elemH[slotId].itemStyleId = itemStyleId
			elemH[slotId].slotId    = slotId
			elemH[slotId].equipType = equipType
			elemH[slotId].equipLoc  = SLOT_TYPE_REV[slotId]
			elemH[slotId].itemLevel = itemLevel
			--equipslot

			local itemType, specializedItemType = GetItemLinkItemType(itemLink)
			--Returns: number ItemType itemType, number SpecializedItemType specializedItemType 
			elemH[slotId].itemType = itemType
			elemH[slotId].specializedItemType = specializedItemType
			elemH[slotId].armorType = nil
			elemH[slotId].weaponType = nil

			if( itemType == ITEMTYPE_ARMOR ) then
				local armorType = GetItemLinkArmorType(itemLink)
				--Returns: number ArmorType armorType 
				elemH[slotId].armorType = armorType
			end
			if( itemType == ITEMTYPE_WEAPON ) then
				local weaponType = GetItemLinkWeaponType(itemLink)
				--Returns: number WeaponType weaponType 
				elemH[slotId].weaponType = weaponType
			end
		end
	end
end

------------------------------
-- Companions
function EchoESOADatastore.saveCompanionDataInit(playerKey, companionId, cname)	
	EchoESOADatastore.debugMsg("saveCompanionDataInit: playerKey= " .. tostring(playerKey) )
	if(playerKey==nil) then
		EchoESOADatastore.debugMsg("Warn: saveCompanionDataInit called with no playerKey")
		return nil
	end
	if(EchoESOADatastore.svCharDataAW.sections.companions==nil) then
		EchoESOADatastore.svCharDataAW.sections.companions = {}
		EchoESOADatastore.outputMsg("saveCompanionDataInit: AW= " .. tostring(EchoESOADatastore.svCharDataAW.sections.companions) )
	end
	local sectionElem = EchoESOADatastore.svCharDataAW.sections.companions
	--EchoESOADatastore.debugMsg("saveCompanionDataInit: AW2= " .. tostring(EchoESOADatastore.svCharDataAW.sections.companions) )
	if(sectionElem[playerKey]==nil) then	
		EchoESOADatastore.outputMsg("saveCompanionDataInit: playerKey= ",playerKey, " companionId=",companionId, " cname=",cname)
		EchoESOADatastore.svCharDataAW.sections.companions[playerKey] = {}
		sectionElem = EchoESOADatastore.svCharDataAW.sections.companions
	end
	local playerElem = sectionElem[playerKey]
	EchoESOADatastore.debugMsg("companion save data: companionId: '", companionId, "' as '", cname, "'" )
	----Section: Setup Section
	if( playerElem.ids == nil ) then
		playerElem.ids  = {}
		EchoESOADatastore.debugMsg("companion clear id data: companionId: '", companionId, "' as '", cname, "'" )
	end
	if( playerElem.data == nil ) then
		playerElem.data = {}
	end
	if( playerElem.ids[companionId] == nil ) then
		playerElem.ids[companionId] = companionId
		EchoESOADatastore.debugMsg("companion set id data: companionId: '", companionId, "' as '", cname, "'" )
	end
	if( playerElem.data[companionId] == nil ) then
		playerElem.data[companionId] = {}
	end
	playerElem.data[companionId].id      = companionId
	playerElem.data[companionId].name    = zo_strformat("<<X:1>>", cname )
	--
	EchoESOADatastore.debugMsg("companion save data: companionId: '", companionId, "' fixed as '", zo_strformat("<<X:1>>", cname ), "'" )
	return playerElem
end

------------------------------
--Companions
function EchoESOADatastore.saveCompanionDataLevel(playerKey, companionId, cname, level, currentExperience, experienceForLevel)
	local playerElemC = EchoESOADatastore.saveCompanionDataInit(playerKey, companionId, cname)	
	EchoESOADatastore.debugMsg("saveCompanionDataLevel: playerKey= " .. tostring(playerKey) )
	if(playerElemC==nil) then
		return
	end
	--
	EchoESOADatastore.debugMsg("saveCompanionDataLevel: playerKey= " .. tostring(playerKey) )
	-- TODO Remove local saving of exp/lvl
	playerElemC.data[companionId].level              = nil
	playerElemC.data[companionId].currentExperience  = nil
	playerElemC.data[companionId].experienceForLevel = nil
	--
	-- Account Level Data
	--
	local dName 	= GetDisplayName() -- TODO cache or pass this
	if(EchoESOADatastore.svESOADataAW[dName].companions==nil) then
		EchoESOADatastore.svESOADataAW[dName].companions = {}
	end
	if(EchoESOADatastore.svESOADataAW[dName].companions[companionId]==nil) then
		EchoESOADatastore.svESOADataAW[dName].companions[companionId] = {}
	end
	local accountCompanionsElem = EchoESOADatastore.svESOADataAW[dName].companions
	--EchoESOADatastore.outputMsg("saveCompanionDataLevel: dName=" , tostring(dName), " companionId=", tostring(companionId)   )
	accountCompanionsElem[companionId].name					= cname
	accountCompanionsElem[companionId].level				= level
	accountCompanionsElem[companionId].currentExperience  	= currentExperience
	accountCompanionsElem[companionId].experienceForLevel 	= experienceForLevel
	--
end

------------------------------
--Companions
function EchoESOADatastore.saveCompanionDataSkillRank(playerKey, companionId, cname, skillLineId, slName, rank )
	EchoESOADatastore.debugMsg("saveCompanionDataSkillRank: Called")
	local playerElemC = EchoESOADatastore.saveCompanionDataInit(playerKey, companionId, cname)	
	EchoESOADatastore.debugMsg("saveCompanionDataSkillRank: playerKey= " .. tostring(playerKey) )
	if(playerElemC==nil) then
		return
	end
	--
	EchoESOADatastore.saveCompanionDataSkillLine(playerKey, companionId, cname, skillLineId, slName )
	playerElemC.data[companionId].skillline[skillLineId].rank = rank
end

------------------------------
--Companions
function EchoESOADatastore.saveCompanionDataSkillLine(playerKey, companionId, cname, skillLineId, slName )
	EchoESOADatastore.debugMsg("saveCompanionDataSkillLine: Called")
	local playerElemC = EchoESOADatastore.saveCompanionDataInit(playerKey, companionId, cname)	
	EchoESOADatastore.debugMsg("saveCompanionDataSkillLine: playerKey= " .. tostring(playerKey) )
	if(playerElemC==nil) then
		return
	end
	--
	if(playerElemC.data[companionId].skillline == nil) then
		playerElemC.data[companionId].skillline = {}
	end
	if(playerElemC.data[companionId].skillline[skillLineId] == nil ) then
		playerElemC.data[companionId].skillline[skillLineId] = {}
	end
	playerElemC.data[companionId].skillline[skillLineId].id   = skillLineId
	playerElemC.data[companionId].skillline[skillLineId].name = slName
end

------------------------------
--Companions
function EchoESOADatastore.saveCompanionDataRapport(playerKey, companionId, cname, currentRapport)
	EchoESOADatastore.debugMsg("saveCompanionDataRapport:[",playerKey,"] compid=",companionId," cname=",cname, " rapp=", tostring(currentRapport) )
	local playerElemC = EchoESOADatastore.saveCompanionDataInit(playerKey, companionId, cname)
	if(playerElemC==nil) then
		return
	end
	--
	playerElemC.data[companionId].id      = companionId
	playerElemC.data[companionId].name    = cname
	playerElemC.data[companionId].rapport = currentRapport
end

------------------------------
--
function EchoESOADatastore.saveCharcterTrackingData(characterLineKey, trackingType,trackingName,isCompleted,completedTimeStamp,timeToReset )
	EchoESOADatastore.debugMsg("SaveTrackingData: character=",tostring(characterLineKey)," type=",tostring(trackingType)," name='", tostring(trackingName),"'")
	EchoESOADatastore.checkNullData(characterLineKey)
	--
	if( EchoESOADatastore.svCharDataAW.tracking == nil ) then
		EchoESOADatastore.svCharDataAW.tracking = {}
	end
	if( EchoESOADatastore.svCharDataAW.tracking[characterLineKey] == nil ) then
		EchoESOADatastore.svCharDataAW.tracking[characterLineKey] = {}
	end
	if( EchoESOADatastore.svCharDataAW.tracking[characterLineKey][trackingType] == nil ) then
		EchoESOADatastore.svCharDataAW.tracking[characterLineKey][trackingType] = {}
	end
	if( EchoESOADatastore.svCharDataAW.tracking[characterLineKey][trackingType][trackingName] == nil ) then
		EchoESOADatastore.svCharDataAW.tracking[characterLineKey][trackingType][trackingName] = {}
	end
	local trackElem = EchoESOADatastore.svCharDataAW.tracking[characterLineKey][trackingType][trackingName]
	--
	trackElem.name          = trackingName
	--trackElem.cat           = trackingType
	trackElem.completed     = isCompleted
	trackElem.completedtime = completedTimeStamp
	--local hour, minute = ElderScrollsOfAlts:dailyReset()
	--local timeToReset = hour*3600 + minute*60
	trackElem.resettime     = trackElem.completedtime + timeToReset
	--trackElem.resettime     = GetTimeStamp today at 10am UTC NA for 3am UTC EU ??
	-- TODO EU NA
	--timeToReset = 5*3600 + 0*60
	--trackElem.resettime     = timeToReset
end

------------------------------
------------------------------