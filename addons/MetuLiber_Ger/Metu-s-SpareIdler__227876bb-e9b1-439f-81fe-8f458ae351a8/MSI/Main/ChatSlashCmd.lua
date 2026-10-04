-- ChatSlashCmd.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

--****************--
-- Chat Slash Cmds
function MSI.InitSlashCmdLibrary()
	MSI.LSC = LibSlashCommander
	if not MSI.LSC then
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LSC_FAILURE)))
	else
		MSI.Print("d", string.format("%s", GetString(MSI_LOAD_LIB_LSC_SUCCESS)))
	end
end

function MSI.InitSlashChatCmnds()
	if not MSI.LSC then
		-- Fallback to registering slash commands with the original method
		SLASH_COMMANDS["/msi"] = function() MSI.ShowCenterMsg(2468, [[rene_metu.dds]], "Metu und René beim ESO AddOn Testen!!") end
		SLASH_COMMANDS["/msibook"] = function() MSI.MSIBook() end
		SLASH_COMMANDS["/msilawful"] = function() MSI.MSILawfulBehave() end
--		SLASH_COMMANDS["/msiicon"] = function() MSI.ShowZoneIcon() end
	else
		-- Register slash commands with LibSlashCommander
		MSI.LSC:Register("/msi", function() MSI.ShowCenterMsg(2468, [[rene_metu.dds]], "Metu und René beim AddOn-Testen!!") end, "CenterMsg: /msi")
		MSI.LSC:Register("/msibook", function() MSI.MSIBook() end, GetString(MSI_MOD_BOOK_INHIBITER_SWITCH))
		MSI.LSC:Register("/msilawful", function() MSI.MSILawfulBehave() end, GetString(MSI_MOD_LAWFUL_BEHAVE_SWITCH))
--		MSI.LSC:Register("/msiicon", function() MSI.ShowZoneIcon() end, "IconTest: /msiicon")
	end
end
--eof