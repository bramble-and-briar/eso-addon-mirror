-- The first file the game runs for this add-on. It keeps a trace of how far start-up got and answers /pbwrit with it
-- until the add-on proper takes the command over.
--
-- Why: an add-on whose files do not run, or whose start-up does not happen, shows nothing and says nothing, and a
-- writ helper is idle most of the time, so from the outside that cannot be told from one that is merely waiting.
-- This file depends on no other file: if /pbwrit answers at all, the game is running this add-on's Lua, and the
-- answer says which later files ran and whether start-up happened. If /pbwrit does not answer, the game is not running
-- these files and no code in them can be at fault.
local NAME = "PBsCraftAssistant"
local EXPECTED = { "Boot", "strings", "Core", "Writs", "Dialog", "Craft", "Bank", "Rewards", "Panel", "Settings", "Main" }

PBS_CA_BOOT = {
	name = NAME,
	files = {}, -- files that ran to their last line, in order
	announced = 0, -- EVENT_ADD_ON_LOADED events seen, for any add-on
	ours = false, -- one of them was for this add-on's name
	activated = 0, -- EVENT_PLAYER_ACTIVATED seen
	init = nil, -- how start-up happened
}
local B = PBS_CA_BOOT

-- Every file calls this as its last line, so a file that errors halfway is not counted as run.
function PBS_CA_MARK(file)
	B.files[#B.files + 1] = file
end
PBS_CA_MARK("Boot")

function B.Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	elseif d then
		d(text)
	end
end

function B.Lines()
	local lines = {}
	local A = PBS_CRAFT_ASSIST
	lines[#lines + 1] = "start-up trace" .. (A and A.title and (" of " .. A.title) or "")
	local seen = {}
	for _, file in ipairs(B.files) do
		seen[file] = true
	end
	local missing = {}
	for _, file in ipairs(EXPECTED) do
		if not seen[file] then
			missing[#missing + 1] = file
		end
	end
	lines[#lines + 1] = "files run to the end: " .. table.concat(B.files, ", ")
		.. (#missing > 0 and ("   MISSING: " .. table.concat(missing, ", ")) or "")
	lines[#lines + 1] = string.format("the game announced %d add-ons; this one (as \"%s\"): %s", B.announced, NAME,
		B.ours and "yes" or "NO")
	lines[#lines + 1] = "started up: " .. (B.init or "NO") .. "; EVENT_PLAYER_ACTIVATED seen " .. B.activated .. " time(s)"
	if A and A.lastError then
		lines[#lines + 1] = "last error - " .. tostring(A.lastError)
	end
	return lines
end

function B.Print()
	for _, line in ipairs(B.Lines()) do
		B.Say(line)
	end
end

if SLASH_COMMANDS then
	SLASH_COMMANDS["/pbwrit"] = B.Print
	SLASH_COMMANDS["/pbcraftassist"] = B.Print
end
