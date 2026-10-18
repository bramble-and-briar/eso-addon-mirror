-- PB's FurnitureEditor
-- Author: PinkBanther
--
-- ---------------------------------------------------------------------------------------
-- THE PROBLEM
-- ---------------------------------------------------------------------------------------
--
-- A build made of linked furnishings -- a table with everything on it, a bookcase with its
-- books, a whole fountain -- takes an evening to make and cannot be carried to another
-- house. The game has no copy button. On a PC, add-ons can already do it; this is the same
-- job on a console, where one real test costs a whole session.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THE CLIENT GIVES US (all of it public; see FINDINGS.md for the evidence)
-- ---------------------------------------------------------------------------------------
--
--   read     GetNextPlacedHousingFurnitureId, GetPlacedHousingFurnitureInfo,
--            HousingEditorGetFurnitureWorldPosition / Orientation,
--            GetPlacedFurnitureParent / GetPlacedFurnitureChildren
--   write    HousingEditorRequestItemPlacement, HousingEditorRequestCollectiblePlacement,
--            HousingEditorRequestChangePositionAndOrientation,
--            HousingEditorRequestSetFurnitureParent
--
-- The four write calls, and the two link calls among the readers, are called from nowhere in
-- the client's own Lua. The official editor goes through a ghost object and the reticle;
-- these take a position and do it. They are not marked private, but "not marked" is not
-- "allowed" (SetSetting is unmarked and private), so the first job of this build is to ask
-- the console, one step at a time, which of them it will actually obey. That is /pbfe probe.
--
-- ---------------------------------------------------------------------------------------
-- HOUSE RULES
-- ---------------------------------------------------------------------------------------
--
-- Add-on Lua is insecure code. Nothing here hooks a client function or calls client Lua that
-- builds a screen: every call is a C API function, made through pcall, so that a function the
-- console refuses is a line of chat and not a dead add-on. Nothing is placed, moved, linked
-- or removed except by a command that says so, and a paste is a dry run until it is told "go".
-- ---------------------------------------------------------------------------------------

if PBS_FURNITURE_EDITOR then
	return
end

local addon = {
	name = "PBsFurnitureEditor",
	commands = {},
	helpLines = {},
}

PBS_FURNITURE_EDITOR = addon

local DISPLAY_NAME = "PB's FurnitureEditor"
local SLASH = "/pbfurnitureeditor"
local SHORT_SLASH = "/pbfe"

local DEFAULTS = {
	-- the clipboard: what the last "copy" read, see House.lua for its shape. A paste that places all
	-- of it empties it (Paste.lua, FinishRun); one that leaves something out keeps it.
	clip = nil,
	-- named clipboards, "save <name>" / "load <name>"
	library = {},
	-- what /pbfe calib decided about the client's rotation order, see Geometry.lua
	convention = nil,
	-- the furnishings the last paste placed, so that "undo" can take them away again
	lastPaste = nil,
	-- pastes waiting for a house to be entered, see Reserve.lua
	reservations = {},
	nextReservationId = 1,
	-- Paste / Move on the quickslot wheel while something is waiting in the house, see Wheel.lua
	menu = true,
	-- the most one slot holds of each furnishing kind (by furniture data id), learned from the bags
	-- every time they are looked at, so that a cut can count the slots its furnishings will need
	stackMax = {},
	-- Copy (circle) and Cut (square) in the housing editor, see Editor.lua
	editorKeys = true,
	-- The clipboard is "fresh" from a copy or cut until it has been pasted; a fresh one puts Paste (or
	-- Move, for a cut) on the quickslot wheel in any house of yours. pasteMode is where the wheel puts
	-- it: aim (where the cursor points, standing in if that cannot be read), here, or same.
	clipFresh = false,
	pasteMode = "aim",
	-- the progress bar for cut, move and paste (Progress.lua): on or off, and where (top, center, bottom)
	progress = true,
	progressAt = "top",
	-- milliseconds between two requests to the server, and how long one may take to answer
	paceMs = 450,
	timeoutMs = 6000,
}

-- ---------------------------------------------------------------------------------------
-- Output
--
-- Everything this build learns has to be readable on a television, so lines are short and
-- each one is a fact rather than a sentence.
-- ---------------------------------------------------------------------------------------

local function Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

local PREFIX = "|cFF69B4" .. DISPLAY_NAME .. "|r: "

local function Line(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		Say(ok and formatted or text)
	else
		Say(text)
	end
end

local function Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		Line(PREFIX .. (ok and formatted or text))
	else
		Line(PREFIX .. text)
	end
end

addon.Say = Say
addon.Line = Line
addon.Print = Print

-- A short message on the screen, for what the player must not miss when the chat is not in view (a console
-- player in the housing editor does not see the chat). The chat is told separately, with Print; this is only
-- the headline. It is the client's own alert (ZO_AlertNoSuppression), called through pcall.
function addon.Alert(text, ...)
	local ok, message = pcall(string.format, text, ...)
	if not ok then
		message = tostring(text)
	end
	if type(ZO_AlertNoSuppression) == "function" and UI_ALERT_CATEGORY_ALERT ~= nil then
		pcall(ZO_AlertNoSuppression, UI_ALERT_CATEGORY_ALERT, nil, message)
	end
end

-- ---------------------------------------------------------------------------------------
-- Calling the client
--
-- Call returns a table of the function's returns, or nil and why not: "missing" when the
-- name does not exist in this build, or the error text when the call was refused. The
-- refusal text is the interesting one -- that is how a private function announces itself.
-- Try1 is the same for the hot loops, where a table per call is too much: first return or nil.
-- ---------------------------------------------------------------------------------------

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil, "missing"
	end

	local packed = { pcall(fn, ...) }
	if not packed[1] then
		return nil, tostring(packed[2])
	end

	table.remove(packed, 1)
	return packed
end

local function Try1(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end

	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function Report(label, fn, ...)
	local results, err = Call(fn, ...)
	if not results then
		Print("%s -> FAILED (%s)", label, err)
		return nil
	end

	if #results == 0 then
		Print("%s -> ok (no return)", label)
	else
		local parts = {}
		for i = 1, #results do
			parts[i] = tostring(results[i])
		end
		Print("%s -> %s", label, table.concat(parts, ", "))
	end

	return results[1]
end

local function Bool(value)
	if value == nil then
		return "nil"
	end
	return value and "yes" or "no"
end

addon.Call = Call
addon.Try1 = Try1
addon.Report = Report
addon.Bool = Bool

-- ---------------------------------------------------------------------------------------
-- id64
--
-- A furniture id is an id64, and an id64 is not a number or a string a table can be keyed by.
-- Two ids for the same furnishing are not promised to compare equal with ==, so every id that
-- is stored, compared or printed goes through Id64ToString first. The id itself is kept for
-- the calls that take one.
-- ---------------------------------------------------------------------------------------

function addon.IdKey(id)
	if id == nil then
		return nil
	end

	if Id64ToString then
		local ok, text = pcall(Id64ToString, id)
		if ok and text ~= nil then
			return text
		end
	end

	return tostring(id)
end

function addon.IsNoId(id)
	if id == nil then
		return true
	end

	if IsId64EqualToNumber then
		local ok, isZero = pcall(IsId64EqualToNumber, id, 0)
		if ok then
			return isZero and true or false
		end
	end

	return id == 0 or id == "0"
end

function addon.SameId(a, b)
	if a == nil or b == nil then
		return false
	end

	if AreId64sEqual then
		local ok, same = pcall(AreId64sEqual, a, b)
		if ok then
			return same and true or false
		end
	end

	return addon.IdKey(a) == addon.IdKey(b)
end

function addon.KeyToId(key)
	if StringToId64 then
		local ok, id = pcall(StringToId64, key)
		if ok then
			return id
		end
	end
	return key
end

-- ---------------------------------------------------------------------------------------
-- Names for the client's answers
--
-- A HousingRequestResult is a number, and "21" teaches nobody anything. The names are
-- generated from ESOUIDocumentation.txt (API 101051) and looked up by global, so a name the
-- client does not have is skipped instead of breaking the table. ResultText is the game's own
-- sentence for it, in the player's language.
-- ---------------------------------------------------------------------------------------

local REQUEST_RESULT_NAMES = {
	"ALREADY_APPLYING_TEMPLATE",
	"ALREADY_BEING_MOVED",
	"ALREADY_SET_TO_MODE",
	"BLOCKED_BY_BLACKLISTED_COLLECTIBLE",
	"FURNITURE_ALREADY_SELECTED",
	"FURNITURE_VAULT_COLLECTIBLE_BLACKLISTED",
	"HIGH_IMPACT_COLLECTIBLE_PLACE_LIMIT",
	"HIGH_IMPACT_ITEM_PLACE_LIMIT",
	"INCORRECT_MODE",
	"INVALID_FURNITURE_POSITION",
	"INVALID_TEMPLATE",
	"INVENTORY_REMOVE_FAILED",
	"IN_COMBAT",
	"IN_SAFE_ZONE",
	"IS_DEAD",
	"ITEM_REMOVE_FAILED",
	"ITEM_REMOVE_FAILED_ALREADY_OWN_UNIQUE",
	"ITEM_REMOVE_FAILED_INVENTORY_FULL",
	"ITEM_STOLEN",
	"KICK_OCCUPANT_SELF",
	"LINK_ALREADY_HAS_PARENT",
	"LINK_ALREADY_LINKED",
	"LINK_FAILED",
	"LINK_HAS_NO_CHILDREN",
	"LINK_HAS_NO_PARENT",
	"LINK_HAS_TOO_MANY_CHILDREN",
	"LINK_INFINITE_PARENT_LOOP",
	"LINK_NO_BAD_LINKAGE",
	"LINK_SAME_FURNITURE",
	"LOW_IMPACT_COLLECTIBLE_PLACE_LIMIT",
	"LOW_IMPACT_ITEM_PLACE_LIMIT",
	"METRICS_LIMIT_HIT",
	"MOVE_FAILED",
	"NOT_IN_HOUSE",
	"NO_CHANGES",
	"NO_DUPLICATES",
	"NO_SUCH_FURNITURE",
	"NO_TARGET",
	"PATH_CANT_RESTART_ALL_PATHS",
	"PATH_FURNITURE_PATHING",
	"PATH_INDEX_OUT_OF_RANGE",
	"PATH_INVALID_FURNITURE",
	"PATH_INVALID_NODE",
	"PATH_MODE_ONLY",
	"PATH_NODE_TOO_CLOSE",
	"PATH_NOT_ENOUGH_NODES",
	"PATH_NO_PATH_DATA",
	"PATH_TOO_MANY_NODES",
	"PATH_TOO_MANY_PATHS",
	"PATH_UNSUPPORTED_PATH_TYPE",
	"PATH_WAIT_TIME_OUT_OF_RANGE",
	"PERMISSIONS_AT_LIMIT_GUILD",
	"PERMISSIONS_AT_LIMIT_INDIVIDUAL",
	"PERMISSIONS_AT_TOTAL_LIMIT",
	"PERMISSION_FAILED",
	"PERSONAL_TEMP_ITEM_PLACE_LIMIT",
	"PLACE_FAILED",
	"REMOVE_FAILED",
	"REQUEST_IN_PROGRESS",
	"REUSE_ME2",
	"REUSE_ME3",
	"SET_STATE_FAILED",
	"SUCCESS",
	"TOTAL_TEMP_ITEM_PLACE_LIMIT",
	"UNKNOWN_FAILURE",
}

local COMMAND_RESULT_NAMES = {
	"COLLECTIBLE_BLACKLISTED",
	"COLLECTIBLE_LOCKED",
	"COMMAND_FAILED",
	"CURRENTLY_INVALID",
	"FURNITURE_BEING_MOVED",
	"FURNITURE_LIMIT_REACHED",
	"INVALID_ITEM",
	"ITEM_IS_UNIQUE",
	"LINK_INVALID",
	"METRICS_CRITICAL",
	"NOT_ENOUGH_INVENTORY_SPACE",
	"PATH_OPERATION_INVALID",
	"SUCCESS",
}

local MODE_NAMES = {
	"BROWSE",
	"DISABLED",
	"LINK",
	"NODE_PLACEMENT",
	"PATH",
	"PLACEMENT",
	"SELECTION",
}

local reverse = {}

local function NameOf(kind, prefix, names, value)
	local map = reverse[kind]
	if not map then
		map = {}
		for _, suffix in ipairs(names) do
			local number = _G[prefix .. suffix]
			if number ~= nil then
				map[number] = suffix
			end
		end
		reverse[kind] = map
	end

	return map[value] or ("?" .. tostring(value))
end

function addon.ResultName(result)
	return NameOf("request", "HOUSING_REQUEST_RESULT_", REQUEST_RESULT_NAMES, result)
end

function addon.CommandResultName(result)
	return NameOf("command", "HOUSING_EDITOR_COMMAND_RESULT_", COMMAND_RESULT_NAMES, result)
end

function addon.ModeName(mode)
	return NameOf("mode", "HOUSING_EDITOR_MODE_", MODE_NAMES, mode)
end

-- "NAME (the game's sentence)"; the sentence is left out when the client has none.
function addon.ResultText(result)
	local name = addon.ResultName(result)
	local text = Try1(GetString, "SI_HOUSINGREQUESTRESULT", result)
	if type(text) == "string" and text ~= "" then
		return name .. " (" .. text .. ")"
	end
	return name
end

function addon.IsSuccess(result)
	return result == HOUSING_REQUEST_RESULT_SUCCESS
end

-- ---------------------------------------------------------------------------------------
-- Time
-- ---------------------------------------------------------------------------------------

function addon.Now()
	return Try1(GetGameTimeMilliseconds) or Try1(GetFrameTimeMilliseconds) or 0
end

function addon.Later(ms, fn)
	return zo_callLater(fn, ms)
end

-- Names come back from the client with grammar markup in some languages.
function addon.Clean(name)
	if type(name) ~= "string" then
		return tostring(name or "?")
	end

	if zo_strformat then
		local ok, text = pcall(zo_strformat, "<<1>>", name)
		if ok and type(text) == "string" and text ~= "" then
			return text
		end
	end

	return name
end

function addon.Round(value)
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return -math.floor(-value + 0.5)
end

-- ---------------------------------------------------------------------------------------
-- Commands
--
-- Every file registers its own commands here, so the help text cannot drift from what exists.
-- ---------------------------------------------------------------------------------------

function addon:AddCommand(name, usage, fn)
	self.commands[name] = fn
	if usage then
		self.helpLines[#self.helpLines + 1] = usage
	end
end

function addon:PrintHelp()
	Print("copy linked furnishings between your houses (v1.0.6)")
	for _, text in ipairs(self.helpLines) do
		Line(text)
	end
end

function addon:HandleCommand(argumentString)
	local words = {}
	for word in string.gmatch(argumentString or "", "%S+") do
		words[#words + 1] = string.lower(word)
	end

	local command = table.remove(words, 1)
	if not command or command == "help" then
		self:PrintHelp()
		return
	end

	local handler = self.commands[command]
	if not handler then
		Print("unknown: %s", command)
		self:PrintHelp()
		return
	end

	local ok, err = pcall(handler, self, words)
	if not ok then
		Print("%s failed: %s", command, tostring(err))
	end
end

-- ---------------------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------------------

function addon:Initialise()
	self.sv = ZO_SavedVars:NewAccountWide("PBsFurnitureEditor_Data", 1, nil, DEFAULTS)

	SLASH_COMMANDS[SLASH] = function(argumentString)
		self:HandleCommand(argumentString)
	end
	SLASH_COMMANDS[SHORT_SLASH] = SLASH_COMMANDS[SLASH]

	if self.OnInitialise then
		self:OnInitialise()
	end
	if self.OnInitialiseEditor then
		self:OnInitialiseEditor()
		self:EnsureEditorKeys()
	end

	-- the settings panel needs LibHarvensAddonSettings, which is optional; a failure to build it is no reason
	-- for anything else to stop
	if self.InitSettings then
		local ok, err = pcall(self.InitSettings, self)
		if not ok then
			Print("the settings panel could not be built: %s", tostring(err))
		end
	end
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, function(_, addOnName)
	if addOnName ~= addon.name then
		return
	end

	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)
	addon:Initialise()
end)
