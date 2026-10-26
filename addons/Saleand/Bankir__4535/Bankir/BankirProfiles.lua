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

local function createNewProfile(name)
	BankirSavedVariables.Profiles = BankirSavedVariables.Profiles or {}
	BankirSavedVariables.Profiles[name] = BankirSavedVariables.Profiles[name] or Bankir.Data.getDefaultProfileSettings()
	Bankir.savedVarsProfile = BankirSavedVariables.Profiles[name]
	Bankir.savedVarsCharacter.profile = name
	updateProfilesNames()
end

local function copyCurrentProfile()
	local currentVars = BankirSavedVariables.Profiles[Bankir.savedVarsCharacter.profile]
	local newName = Bankir.savedVarsCharacter.profile .. " (Copy)"
	local newVars = Bankir.Functions.getFullCopy(currentVars)
	BankirSavedVariables.Profiles[newName] = newVars
	Bankir.savedVarsProfile = BankirSavedVariables.Profiles[newName]
	Bankir.savedVarsCharacter.profile = newName
	updateProfilesNames()
end

local function deleteCurrentProfile()
	local currentName = Bankir.savedVarsCharacter.profile
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

	Bankir.savedVarsProfile = BankirSavedVariables.Profiles[profilesNames[1]]
	Bankir.savedVarsCharacter.profile = profilesNames[1]
end

local function setCurrentProfile(name)
	Bankir.savedVarsProfile = BankirSavedVariables.Profiles[name]
	Bankir.savedVarsCharacter.profile = name
end

local function updateCurrentProfileName(oldName, newName)
	local oldVars = BankirSavedVariables.Profiles[oldName]
	BankirSavedVariables.Profiles[newName] = oldVars
	Bankir.savedVarsProfile = BankirSavedVariables.Profiles[newName]
	BankirSavedVariables.Profiles[oldName] = nil
	Bankir.savedVarsCharacter.profile = newName
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
	createNewProfile = createNewProfile,
	copyCurrentProfile = copyCurrentProfile,
	deleteCurrentProfile = deleteCurrentProfile,
	setCurrentProfile = setCurrentProfile,
	updateCurrentProfileName = updateCurrentProfileName,
}
