-- PB's PlayerMarkerExtension: the first file in the manifest. It depends on nothing, so that "the game did not run the
-- files" and "the files ran but start-up failed" can be told apart (PB's other add-ons do the same).
--
-- Every file marks itself on its LAST line (A.MARK("File")), so a file that stopped half way is not counted. The slash
-- command is registered right here, at file load, before EVENT_ADD_ON_LOADED: it answers even if everything after this
-- file failed, and says which files ran.
PBS_PME = PBS_PME or {}
local A = PBS_PME

A.name = "PBsPlayerMarkerExtension"
A.slash = "/pbpme"
A.shortSlash = "/pbmarker"
A.loaded = {}
A.fileOrder = {}

function A.MARK(file)
	A.loaded[file] = true
	A.fileOrder[#A.fileOrder + 1] = file
end

function A.Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	elseif d then
		d(text)
	end
end

local function command(text)
	if A.Command then
		A:Command(text)
	else
		A.Say(string.format("PBsPlayerMarkerExtension: start-up has not run. Files that ran: %s", table.concat(A.fileOrder, ", ")))
	end
end
SLASH_COMMANDS[A.slash] = command
SLASH_COMMANDS[A.shortSlash] = command

A.MARK("Boot")
