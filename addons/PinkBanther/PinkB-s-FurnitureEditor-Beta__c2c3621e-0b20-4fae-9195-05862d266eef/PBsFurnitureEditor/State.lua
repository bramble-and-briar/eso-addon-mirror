-- PB's FurnitureEditor -- what the add-on is holding, and letting go of it
--
-- Between a copy or cut and its paste the add-on holds a good deal: the clipboard, a record of the last paste
-- (what "undo" works from), reservations waiting for a house, a trip that has been started, and the offers on
-- the quickslot wheel that follow from them. Normally a paste empties the clipboard by itself. This is for the
-- times it did not (a paste that stopped half way, a cut that was never moved) and for starting clean.
--
-- Nothing here touches a furnishing in a house or an item in a bag, and a saved clipboard (/pbfe save) is never
-- touched: it was kept on purpose. A cut that has not been pasted is different from a copy. Its clipboard is
-- the only record of where its furnishings go, so forgetting it is asked twice.
--
--   /pbfe reset                 forget the copy or cut on the clipboard
--   /pbfe reset all             also the undo record, reservations, a trip, the wheel offers
--   /pbfe reset ... force       without asking a second time
--
-- The settings panel (Settings.lua) calls the same functions.

local addon = PBS_FURNITURE_EDITOR

local Print, Line = addon.Print, addon.Line

-- how long a first press stays "asked", in milliseconds
local CONFIRM_MS = 10000

local function Count(list)
	local n = 0
	for _ in pairs(list or {}) do
		n = n + 1
	end
	return n
end

-- ---------------------------------------------------------------------------------------
-- What is held
-- ---------------------------------------------------------------------------------------

function addon:HeldState()
	local clip = self.sv.clip
	local held = {
		clip = clip and #clip.nodes or 0,
		cut = clip and clip.cut and true or false,
		undo = self.sv.lastPaste and #self.sv.lastPaste.keys or 0,
		reservations = #(self.sv.reservations or {}),
		cutReservations = 0,
		saved = Count(self.sv.library),
		running = self.run and self.run.kind or nil,
		trip = self.jump ~= nil,
	}

	for _, resv in ipairs(self.sv.reservations or {}) do
		if resv.clip and resv.clip.cut then
			held.cutReservations = held.cutReservations + 1
		end
	end

	if held.cut then
		held.standing, held.here = self:CutStatus(clip)
	end
	return held
end

-- What the add-on holds, in chat: the same lines the settings panel's "show" button prints.
function addon:PrintHeldState()
	local held = self:HeldState()

	if held.clip == 0 then
		Print("clipboard: empty")
	elseif held.cut then
		Print("clipboard: a CUT of %d furnishings, not yet pasted", held.clip)
		if held.here and held.standing then
			Line("  %d of them are still standing in this house", held.standing)
		end
	else
		Print("clipboard: a copy of %d furnishings%s", held.clip, self.sv.clipFresh and " (offered on the quickslot wheel)" or "")
	end

	Line("  undo record: %s", held.undo > 0 and (held.undo .. " furnishings") or "none")
	Line("  reservations: %d%s", held.reservations,
		held.cutReservations > 0 and (" (" .. held.cutReservations .. " of them a cut)") or "")
	Line("  saved clipboards: %d (these are never cleared here)", held.saved)
	if held.running then
		Line("  running now: %s (/pbfe stop)", held.running)
	end
	if held.trip then
		Line("  a trip to another house has been started")
	end
end

-- ---------------------------------------------------------------------------------------
-- Letting go
-- ---------------------------------------------------------------------------------------

-- Has the player already been asked this (`what`) within the last few seconds?
local function Confirmed(self, what)
	local armed = self.clearArmed
	self.clearArmed = nil
	return armed ~= nil and armed.what == what and addon.Now() - armed.at <= CONFIRM_MS
end

local function Arm(self, what)
	self.clearArmed = { what = what, at = addon.Now() }
end

local function Refuse(self, text, ...)
	Print(text, ...)
	addon.Alert(text, ...)
end

-- Forget the copy or cut on the clipboard. Returns "cleared", "nothing", "running" or "asked".
function addon:ClearCopyCut(force)
	if self.run then
		Refuse(self, "a %s is running: stop it first (/pbfe stop)", self.run.kind)
		return "running"
	end

	local clip = self.sv.clip
	if not clip then
		self.sv.clipFresh = false
		Print("the clipboard is already empty")
		return "nothing"
	end

	if clip.cut and not force and not Confirmed(self, "copycut") then
		Arm(self, "copycut")
		Print("a CUT of %d furnishings has not been pasted. Forgetting it forgets where they go: what is already", #clip.nodes)
		Print("out of the house stays in your bag, but this add-on can no longer move it. Do it again within %d s to forget it.", CONFIRM_MS / 1000)
		addon.Alert("A cut of %d furnishings is not pasted. Do it again within %d s to forget it", #clip.nodes, CONFIRM_MS / 1000)
		return "asked"
	end

	self.clearArmed = nil
	self.sv.clip = nil
	self.sv.clipFresh = false

	-- an offer to travel and paste this clipboard goes with it
	for index = #(self.tripOffers or {}), 1, -1 do
		if self.tripOffers[index].clip == clip then
			table.remove(self.tripOffers, index)
		end
	end

	Print("%s of %d furnishings forgotten", clip.cut and "the cut" or "the copy", #clip.nodes)
	addon.Alert("%s forgotten (%d furnishings)", clip.cut and "Cut" or "Copy", #clip.nodes)
	if self.MenuRefreshed then
		self:MenuRefreshed()
	end
	return "cleared"
end

-- Forget everything the add-on holds for a paste: the clipboard, the undo record, reservations, a trip, the
-- wheel offers. Saved clipboards stay. Returns "cleared", "running" or "asked".
function addon:ClearAllState(force)
	if self.run then
		Refuse(self, "a %s is running: stop it first (/pbfe stop)", self.run.kind)
		return "running"
	end

	local held = self:HeldState()
	local cuts = (held.cut and 1 or 0) + held.cutReservations

	if cuts > 0 and not force and not Confirmed(self, "all") then
		Arm(self, "all")
		Print("this forgets %d cut%s that %s not been pasted (the clipboard or a reservation holds the only record", cuts, cuts == 1 and "" or "s", cuts == 1 and "has" or "have")
		Print("of where its furnishings go). Do it again within %d s to forget everything.", CONFIRM_MS / 1000)
		addon.Alert("%d cut%s not pasted. Do it again within %d s to forget everything", cuts, cuts == 1 and " is" or "s are", CONFIRM_MS / 1000)
		return "asked"
	end

	self.clearArmed = nil
	self.sv.clip = nil
	self.sv.clipFresh = false
	self.sv.lastPaste = nil
	self.sv.reservations = {}
	self.jump = nil
	self.tripOffers = {}
	self.menuJobs = {}
	if self.CancelQueue then
		self:CancelQueue()
	end

	Print("forgotten: the clipboard (%d), the undo record (%d), %d reservations. Saved clipboards (%d) are kept.",
		held.clip, held.undo, held.reservations, held.saved)
	addon.Alert("Forgot the copy/cut, the undo record and the reservations")
	if self.MenuRefreshed then
		self:MenuRefreshed()
	end
	return "cleared"
end

addon:AddCommand("reset", "  /pbfe reset [all] [force]   forget the copy/cut on the clipboard (all: also undo, reservations, a trip)", function(self, words)
	local force = addon.TakeFlag(words, "force")

	if words[1] == "all" then
		self:ClearAllState(force)
	elseif words[1] == "show" then
		self:PrintHeldState()
	else
		self:ClearCopyCut(force)
	end
end)
