-- The first file the game runs for this add-on. It does almost nothing, on purpose: it keeps a trace of how far
-- start-up got, and answers /pbember with that trace until the add-on proper starts and takes the command over.
--
-- Why it exists: an add-on whose files do not run, or whose start-up does not happen, shows nothing and says
-- nothing, and from the outside that cannot be told from one that is merely waiting for a fight to start. This
-- file depends on no other file, so if /pbember answers at all the game is running this add-on's Lua, and the
-- answer says which of the later files ran, whether the game announced the add-on under the name it was expected
-- under, and whether start-up happened and how. If /pbember does not answer, the game is not running this
-- add-on's files and no code in it can be at fault.
local NAME = "PBsEmber"
local EXPECTED = { "Boot", "strings", "Geometry", "Core", "Puppet", "Ember", "Watch", "Settings", "Main" }

PBS_EMBER_BOOT = {
	name = NAME,
	files = {}, -- files that ran to their last line, in order
	announced = 0, -- EVENT_ADD_ON_LOADED events seen, for any add-on
	ours = false, -- one of them was for this add-on's name
	like = {}, -- names of other announcements that look like this add-on's
	activated = 0, -- EVENT_PLAYER_ACTIVATED seen
	init = nil, -- how start-up happened: "EVENT_ADD_ON_LOADED" or "EVENT_PLAYER_ACTIVATED (fallback)"
}
local B = PBS_EMBER_BOOT

-- Every file calls this as its last line, so a file that errors halfway is not counted as run.
function PBS_EMBER_MARK(file)
	B.files[#B.files + 1] = file
end
PBS_EMBER_MARK("Boot")

-- Does this announced add-on name look like ours (a typo, a shortened or renamed folder)? Byte-wise, no
-- character class and no lower(): see Core.lua, "Text".
function B.Looks(text)
	text = tostring(text or "")
	for _, word in ipairs({ "pbsember", "PBsEmber", "Ember", "ember" }) do
		if text:find(word, 1, true) then
			return true
		end
	end
	return false
end

function B.Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	elseif d then
		d(text)
	end
end

-- The trace, as lines of text.
function B.Lines()
	local lines = {}
	local function add(text)
		lines[#lines + 1] = text
	end
	local A = PBS_EMBER
	add("start-up trace" .. (A and A.title and (" of " .. A.title) or ""))

	local seen, done, missing = {}, {}, {}
	for _, file in ipairs(B.files) do
		done[#done + 1] = file
		seen[file] = true
	end
	for _, file in ipairs(EXPECTED) do
		if not seen[file] then
			missing[#missing + 1] = file
		end
	end
	add("files run to the end: " .. table.concat(done, ", ") .. (#missing > 0 and ("   MISSING: " .. table.concat(missing, ", ")) or ""))
	add(string.format("the game announced %d add-ons; this one (as \"%s\"): %s", B.announced, NAME, B.ours and "yes" or "NO"))
	if #B.like > 0 then
		add("announced under names that look like it: " .. table.concat(B.like, ", "))
	end
	add("started up: " .. (B.init or "NO") .. "; EVENT_PLAYER_ACTIVATED seen " .. B.activated .. " time(s)")
	if A and A.lastError then
		add("last error - " .. tostring(A.lastError))
	end
	return lines
end

function B.Print()
	for _, line in ipairs(B.Lines()) do
		B.Say(line)
	end
end

-- Until the add-on proper starts and takes the command over, this is what /pbember does.
if SLASH_COMMANDS then
	SLASH_COMMANDS["/pbember"] = B.Print
	SLASH_COMMANDS["/pbe"] = B.Print
end
