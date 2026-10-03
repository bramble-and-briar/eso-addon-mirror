SecurePostHook(ADD_ON_MANAGER, "OnShow", function(self)
	local name = self.selectedCharacterEntry.name
	local formattedName = string.gsub(name, "\\", "")
	self:OnCharacterChanged(formattedName, {name=formattedName, allCharacters=false})
end)