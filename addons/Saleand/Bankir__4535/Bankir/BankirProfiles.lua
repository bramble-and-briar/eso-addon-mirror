Bankir = Bankir or {}

local profilesNames = {}

local function updateProfilesNames()
	if BankirSavedVariables and BankirSavedVariables.Profiles then
		profilesNames = {}
		for k, v in pairs(BankirSavedVariables.Profiles) do
			table.insert(profilesNames, k)
		end
	end
end

local function getProfilesNames()
	updateProfilesNames()
	return profilesNames
end

local function initProfile(name)
	BankirSavedVariables.Profiles = BankirSavedVariables.Profiles or {}
	BankirSavedVariables.Profiles[name] = BankirSavedVariables.Profiles[name] or Bankir.Data.getDefaultProfileSettings()
	Bankir.SVProfile = BankirSavedVariables.Profiles[name]
	Bankir.SVCharacter.profile = name
	updateProfilesNames()
end

local function copyCurrentProfile()
	local currentVars = BankirSavedVariables.Profiles[Bankir.SVCharacter.profile]
	local newName = Bankir.SVCharacter.profile .. " (Copy)"
	local newVars = Bankir.Functions.copyData(currentVars)
	BankirSavedVariables.Profiles[newName] = newVars
	Bankir.SVProfile = BankirSavedVariables.Profiles[newName]
	Bankir.SVCharacter.profile = newName
	updateProfilesNames()
end

local function deleteCurrentProfile()
	local currentName = Bankir.SVCharacter.profile
	BankirSavedVariables.Profiles[currentName] = nil
	updateProfilesNames()
	
	-- change profile for all characters if they had the deleted one
	for i = 1, GetNumCharacters() do
		local charName = GetCharacterInfo(i)
		charName = zo_strformat(SI_UNIT_NAME, charName)
		if BankirSavedVariables.Default[GetDisplayName()][charName] and BankirSavedVariables.Default[GetDisplayName()][charName].profile == currentName then
			BankirSavedVariables.Default[GetDisplayName()][charName].profile = profilesNames[1]
		end
	end

	Bankir.SVProfile = BankirSavedVariables.Profiles[profilesNames[1]]
	Bankir.SVCharacter.profile = profilesNames[1]
end

local function setCurrentProfile(name)
	Bankir.SVProfile = BankirSavedVariables.Profiles[name]
	Bankir.SVCharacter.profile = name
end

local function updateCurrentProfileName(oldName, newName)
	local oldVars = BankirSavedVariables.Profiles[oldName]
	BankirSavedVariables.Profiles[newName] = oldVars
	Bankir.SVProfile = BankirSavedVariables.Profiles[newName]
	BankirSavedVariables.Profiles[oldName] = nil
	Bankir.SVCharacter.profile = newName
	updateProfilesNames()
	
	-- change profile for all characters if they had the renamed one
	for i = 1, GetNumCharacters() do
		local charName = GetCharacterInfo(i)
		charName = zo_strformat(SI_UNIT_NAME, charName)
		if BankirSavedVariables.Default[GetDisplayName()][charName] and BankirSavedVariables.Default[GetDisplayName()][charName].profile == oldName then
			BankirSavedVariables.Default[GetDisplayName()][charName].profile = newName
		end
	end
end

Bankir.Profiles = {
	updateProfilesNames = updateProfilesNames,
	getProfilesNames = getProfilesNames,
	initProfile = initProfile,
	copyCurrentProfile = copyCurrentProfile,
	deleteCurrentProfile = deleteCurrentProfile,
	setCurrentProfile = setCurrentProfile,
	updateCurrentProfileName = updateCurrentProfileName,
}
