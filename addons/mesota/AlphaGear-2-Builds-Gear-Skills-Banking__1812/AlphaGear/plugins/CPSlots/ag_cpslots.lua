------------------------------------------------------------------------------------------------------------------------
-- Global AlphaGear variable
------------------------------------------------------------------------------------------------------------------------
AG = AG or {}
AG.plugins = AG.plugins or {}

------------------------------------------------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------------------------------------------------
--Integration/Plugin coding for Champion Point Slots addon.
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- Global variables
------------------------------------------------------------------------------------------------------------------------
AG.plugins.CPSlots = AG.plugins.CPSlots or {}

------------------------------------------------------------------------------------------------------------------------
-- const
------------------------------------------------------------------------------------------------------------------------
local CPS_HOST_USERS = 'Users'
local CPS_HOST_USERS_ACCOUNT = "UsersAccount"
-- local CPS_HOST_TRIAL = "Trial"
-- local CPS_HOST_TRIAL_ALCAST = "TrialAlcast"
-- local CPS_HOST_TRIAL_NEFAS = "TrialNefas"

------------------------------------------------------------------------------------------------------------------------
-- Local variables
------------------------------------------------------------------------------------------------------------------------
--Local "speed up" variables
local AGplugCPS = AG.plugins.CPSlots

AGplugCPS.CPS_KEEP = '$$KEEPCPS$$'

-- Hosts map: host-key => {label, slot-table, name-table}
-- will be filled on init
AGplugCPS.HOSTS = {
	[CPS_HOST_USERS] = {},
	[CPS_HOST_USERS_ACCOUNT] = {}
}


------------------------------------------------------------------------------------------------------------------------
-- Functions
------------------------------------------------------------------------------------------------------------------------

--- Writes trace messages to the console
-- fmt with %d, %s,
local function trace(fmt, ...)
	if AG.isDebug then
		d(string.format(fmt, ...))
	end
end

function AGplugCPS.isAddonReady()
	return (CPS ~= nil and CPS.setCPBuild ~= nil) or false
end

function AGplugCPS.useAddon()
	return AGplugCPS.isAddonReady() and AG.account.Integrations.Champion.UseCPSlots or false
end

function AGplugCPS.LoadCPSProfile(hostKey, newProfileName)
	if not AGplugCPS.useAddon() then
		return
	end

	if hostKey ~= AGplugCPS.CPS_KEEP and hostKey ~= nil and hostKey ~= "" then
		AGplugCPS.LoadCPSSlots()

		-- find slot by host and name
		local host = AGplugCPS.HOSTS[hostKey]

		if host then
			for id, profileName in pairs(host.nameMap) do
				if newProfileName == profileName then
					CPS.currentSetName = newProfileName
					CPS.currentSlot = host.slotTable[id]
					CPS.currentType = host.type

					CPS:setCPBuild(CPS.currentSlot, false)
					d(zo_strformat("|cFFFFFFCP set <<1>> / <<2>> loaded.|r", hostKey, newProfileName)) 
					return
				end
			end
		end

		-- host/profile was not found
		d(zo_strformat("|cFF0000CP set <<1>> / <<2>> was not found...|r", hostKey, newProfileName)) 
	end
end

--[[
function AGplugCPS.HasProfileChanged(newProfile)
	local cpBuffer = {
		[1] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[2] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[3] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[4] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[5] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[6] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[7] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[8] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 } ,
		[9] = { [5] = true, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	}

	-- save current config
	ChampionPointsSlots:saveCurrentCP(cpBuffer, true)

	-- compare current vs. new
	for dis = 1, GetNumChampionDisciplines() do
		for skill = 1, GetNumChampionDisciplineSkills() - ChampionPointsSlots.IGNORE_SPECIAL_SKILLS do
			-- chek if somthing has changed in the new profile
			if (newProfile[dis][ChampionPointsSlots.SKIP_INDEX]) then
				if newProfile[dis][skill] ~= cpBuffer[dis][skill] then
					return true
				end
			end
        end
    end

	-- nothing has changed
	return false
end

--]]

function AGplugCPS.GetCPSProfiles()
	local CPSProfiles = {}
	
	AGplugCPS.LoadCPSSlots()

	-- copy names of profiles
	for key, host in pairs(AGplugCPS.HOSTS) do
		local hostInfo = {}

		hostInfo.label = host.label
		hostInfo.names = {}
	
		for id, name in pairs(host.nameMap) do
			hostInfo.names[id] = name
		end

		CPSProfiles[key] = hostInfo
	end

    return CPSProfiles
end


-- initialization
function AGplugCPS.LoadCPSSlots()
	for key, host in pairs(AGplugCPS.HOSTS) do
		if key == CPS_HOST_USERS then
			host.label = "Users"
			host.slotTable = CPS.sv.Users or {}
			host.nameMap = CPS.sv.MapIndexToName or {}
			host.type = CPS.USER_PROF
		elseif key == CPS_HOST_USERS_ACCOUNT then
			host.label = "Users Account Wide"
			host.slotTable = CPS.svAccount.UsersAccount  or {}
			host.nameMap = CPS.svAccount.MapIndexToAccountName or {}
			host.type = CPS.ACCOUNT_PROF

--[[			
		elseif key == CPS_HOST_TRIAL then
			host.label = "Trial"
			host.slotTable = ChampionPointsSlots.sv.Trial
			host.nameMap = ChampionPointsSlots.sv.MapIndexToTrial
		elseif key == CPS_HOST_TRIAL_ALCAST then
			host.label = "Trial By Alcast"
			host.slotTable = ChampionPointsSlots.sv.TrialByAlcast
			host.nameMap = ChampionPointsSlots.sv.MapIndexToAlcast
		elseif key == CPS_HOST_TRIAL_NEFAS then
			host.label = "Trial By Nefas"
			host.slotTable = ChampionPointsSlots.sv.TrialbyNefasQS
			host.nameMap = ChampionPointsSlots.sv.MapIndexToNefas
--]]			
		end
	end
end
