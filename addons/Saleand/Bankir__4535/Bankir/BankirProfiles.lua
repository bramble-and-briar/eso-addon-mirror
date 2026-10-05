Bankir = Bankir or {}

local profilesNames = {}

local function updateProfilesNames()
	if BankirSavedVariables and BankirSavedVariables.Default.Profiles then
		profilesNames = {}
		for k, v in pairs(BankirSavedVariables.Default.Profiles) do
			table.insert(profilesNames, k)
		end
	end
end

local function getProfilesNames()
	updateProfilesNames()
	return profilesNames
end

local function createNewProfile(name)
	Bankir.savedVars = ZO_SavedVars:New("BankirSavedVariables", 2, nil, Bankir.Data.getDefaultSettings(), "Default", "Profiles", name)
	Bankir.savedVarsCharacter.profile = name
	updateProfilesNames()
end

local function copyCurrentProfile()
	local currentVars = BankirSavedVariables.Default.Profiles[Bankir.savedVarsCharacter.profile]
	Bankir.savedVars = ZO_SavedVars:New("BankirSavedVariables", 2, nil, currentVars, "Default", "Profiles", Bankir.savedVarsCharacter.profile .. " (Copy)")
	Bankir.savedVarsCharacter.profile = Bankir.savedVarsCharacter.profile .. " (Copy)"
	updateProfilesNames()
end

local function deleteCurrentProfile()
	local currentName = Bankir.savedVarsCharacter.profile
	BankirSavedVariables.Default.Profiles[currentName] = nil
	updateProfilesNames()
	Bankir.savedVars = BankirSavedVariables.Default.Profiles[profilesNames[1]]
	Bankir.savedVarsCharacter.profile = profilesNames[1]
	
	-- change profile for all characters if they had the deleted one
	for i = 1, GetNumCharacters() do
		local charName = GetCharacterInfo(i)
		charName = zo_strformat(SI_UNIT_NAME, charName)
		if BankirSavedVariables.Default[GetDisplayName()][charName] and BankirSavedVariables.Default[GetDisplayName()][charName].profile == currentName then
			BankirSavedVariables.Default[GetDisplayName()][charName].profile = profilesNames[1]
		end
	end
end

local function setCurrentProfile(name)
	Bankir.savedVars = BankirSavedVariables.Default.Profiles[name]
	Bankir.savedVarsCharacter.profile = name
end

local function updateCurrentProfileName(oldName, newName)
	local oldVars = BankirSavedVariables.Default.Profiles[oldName]
	Bankir.savedVars = ZO_SavedVars:New("BankirSavedVariables", 2, nil, oldVars, "Default", "Profiles", newName)
	BankirSavedVariables.Default.Profiles[oldName] = nil
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
