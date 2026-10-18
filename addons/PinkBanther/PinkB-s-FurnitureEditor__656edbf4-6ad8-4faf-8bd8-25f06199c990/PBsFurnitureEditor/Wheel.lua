-- PB's FurnitureEditor -- Paste and Move on the quickslot wheel
--
-- A console has no keyboard, and a paste is five words. So when you arrive in a house that has
-- something waiting for it, the quickslot wheel (hold the quickslot button) grows up to two
-- entries, Paste and Move; point at one and let go, and it is done with you standing where you are
-- (so "here" finally means something). When nothing is left to do, the wheel is the game's again.
--
-- What the client's own code says about that wheel (esoui/ingame/utilitywheel, zo_radialmenu):
--
--   * UTILITY_WHEEL_GAMEPAD / UTILITY_WHEEL_KEYBOARD are interactive radial menus. Holding the
--     button calls ShowMenu: Clear, PopulateMenu, Show. Letting go calls the highlighted entry's
--     callback. Entries are added with menu:AddEntry(name, icon, activeIcon, callback, data) and
--     laid out evenly, whatever their number.
--   * Every entry is drawn by SetupEntryControl(control, data), which reads data.slotNum through
--     GetSlotItemCount / GetSlotType / GetSlotCooldownInfo / GetSlotTexture. The game's own EMPTY
--     entries go through the same path with the number of an empty slot, so an entry here borrows
--     one -- and if none is free, an out-of-range one, but only after asking those four calls
--     whether they cope with it.
--   * The accessible (togglable) wheel gives each entry a hotkey, ACCESSIBLE_WHEEL_HOTKEY_SLOT_1
--     to _10, and asserts on more. The quickslot wheel has 8 slots, so two entries fit, and no more.
--     That is why there are exactly two: Paste and Move, each standing for everything waiting of
--     its kind in this house.
--
-- How it hooks, since the house rules forbid hooking: ZO_PreHook / ZO_PostHook replace a client
-- function with one that runs add-on code inside the client's own call chain, and a tainted chain
-- takes protected calls (UseItem, SelectSlotItem) down with it. SecurePostHook is the documented
-- alternative that runs after the original, apart from its chain. It is installed once, only when
-- something is first waiting, and is inert whenever there is nothing to offer. A hook cannot be
-- removed, so "temporary" means: the entries are added only while there is something to do. Anything
-- unexpected stops it, for good, with a message; the commands go on working.
--
-- The entry's callback runs in the client's selection. It does nothing but schedule: the paste
-- itself starts a moment later, outside the client's call chain.

local addon = PBS_FURNITURE_EDITOR

local Call, Try1 = addon.Call, addon.Try1
local Print, Line = addon.Print, addon.Line

-- The accessible wheel has ten hotkeys. The quickslot wheel itself has eight slots.
local MAX_WHEEL_ENTRIES = 10

local ICONS = {
	paste = "EsoUI/Art/Housing/Keyboard/furniture_tabIcon_place_up.dds",
	move = "EsoUI/Art/Housing/Keyboard/furniture_tabIcon_recall_up.dds",
}

local NAMES = {
	en = { paste = "Paste", move = "Move" },
	jp = { paste = "ペースト", move = "ムーブ" },
}

local function Names()
	return NAMES[Try1(GetCVar, "language.2")] or NAMES.en
end

-- ---------------------------------------------------------------------------------------
-- What there is to offer
--
-- Worked out from the current house every time it is asked, so there is no state to go stale:
--   * reservations waiting for this house (a copy is a Paste, a move is a Move), and
--   * pastes that travelled here and only showed their plan (a "trip offer"), because the
--     player has not yet said where to stand.
-- Only in a house the player owns, since only there can anything be placed.
-- ---------------------------------------------------------------------------------------

function addon:CurrentOffers()
	local offers = { paste = {}, move = {} }

	local houseId = Try1(GetCurrentZoneHouseId) or 0
	if houseId == 0 or not Try1(IsOwnerOfCurrentHouse) then
		return offers
	end

	for _, resv in ipairs(self:ReservationsFor(houseId)) do
		local kind = resv.kind == "move" and "move" or "paste"
		offers[kind][#offers[kind] + 1] = {
			source = "reservation",
			label = resv.label,
			words = resv.words,
			clip = resv.clip,
			meta = { reservationId = resv.id },
		}
	end

	-- The clipboard, until it has been pasted: Paste for a copy, Move for a cut. In any house of yours.
	local clip = self.sv.clip
	if self.sv.clipFresh and clip and clip.nodes and #clip.nodes > 0 then
		local kind = clip.cut and "move" or "paste"
		local first = clip.nodes[1]
		offers[kind][#offers[kind] + 1] = {
			source = "clipboard",
			label = string.format("%s (%d)", first.name or "?", #clip.nodes),
			words = { self.sv.pasteMode or "aim" },
			clip = clip,
			meta = { clipboard = true },
		}
	end

	for _, trip in ipairs(self.tripOffers or {}) do
		if trip.houseId == houseId then
			local kind = trip.clip.cut and "move" or "paste"
			offers[kind][#offers[kind] + 1] = {
				source = "trip",
				trip = trip,
				label = trip.label,
				words = trip.words,
				clip = trip.clip,
			}
		end
	end

	return offers
end

-- Is there a fresh clipboard (a copy or cut not yet pasted)?
function addon:HasClipboardOffer()
	local clip = self.sv.clip
	return (self.sv.clipFresh and clip and clip.nodes and #clip.nodes > 0) and true or false
end

-- A paste that travelled here but only showed its plan. The wheel offers it once the player has
-- walked to where it belongs.
function addon:AddTripOffer(houseId, clip, words)
	self.tripOffers = self.tripOffers or {}

	for index = #self.tripOffers, 1, -1 do
		if self.tripOffers[index].clip == clip then
			table.remove(self.tripOffers, index)
		end
	end

	local first = clip.nodes[1]
	self.tripOffers[#self.tripOffers + 1] = {
		houseId = houseId,
		clip = clip,
		words = words,
		label = string.format("%s (%d)", first and first.name or "?", #clip.nodes),
	}
end

local function Count(offers)
	return #offers.paste + #offers.move
end

local function Describe(offers)
	local names = Names()
	local parts = {}
	if #offers.paste > 0 then
		parts[#parts + 1] = string.format("%s (%d)", names.paste, #offers.paste)
	end
	if #offers.move > 0 then
		parts[#parts + 1] = string.format("%s (%d)", names.move, #offers.move)
	end
	return table.concat(parts, " / ")
end

-- ---------------------------------------------------------------------------------------
-- Hooking the wheel
-- ---------------------------------------------------------------------------------------

-- The slot number the entries are drawn with: one that the client's four slot calls certainly cope
-- with and that holds nothing, so no item count and no cooldown are drawn for it.
function addon:PickWheelSlot()
	local category = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
	if category == nil then
		return nil, "no quickslot wheel category"
	end
	local size = ACTION_BAR_UTILITY_BAR_SIZE or 8

	local function usable(slot)
		local slotType = Call(GetSlotType, slot, category)
		local count = Call(GetSlotItemCount, slot, category)
		local cooldown = Call(GetSlotCooldownInfo, slot, category)
		local texture = Call(GetSlotTexture, slot, category)
		return slotType ~= nil and count ~= nil and cooldown ~= nil and texture ~= nil
			and slotType[1] == ACTION_TYPE_NOTHING
	end

	for slot = 1, size do
		if usable(slot) then
			return slot
		end
	end
	if usable(size + 1) then
		return size + 1
	end

	return nil, "no empty quickslot to borrow, and the client does not accept an out-of-range one"
end

-- Returns true, or false and why not. Safe to call again.
function addon:InstallWheelHook()
	if self.wheelHooked then
		return true
	end
	if self.wheelBroken then
		return false, self.wheelBroken
	end

	if type(SecurePostHook) ~= "function" then
		return false, "SecurePostHook is not available in this build"
	end

	local wheels = {}
	for _, name in ipairs({ "UTILITY_WHEEL_GAMEPAD", "UTILITY_WHEEL_KEYBOARD" }) do
		local wheel = _G[name]
		if type(wheel) == "table" and type(wheel.PopulateMenu) == "function" and type(wheel.menu) == "table" then
			wheels[#wheels + 1] = wheel
		end
	end
	if #wheels == 0 then
		return false, "the quickslot wheel was not found"
	end

	local slot, why = self:PickWheelSlot()
	if not slot then
		return false, why
	end
	self.wheelSlot = slot

	for _, wheel in ipairs(wheels) do
		local ok, err = pcall(SecurePostHook, wheel, "PopulateMenu", function(populated)
			addon:OnWheelPopulate(populated)
		end)
		if not ok then
			self.wheelBroken = "SecurePostHook refused: " .. tostring(err)
			return false, self.wheelBroken
		end
	end

	self.wheelHooked = true
	return true
end

-- Runs after the client has filled the wheel, apart from the client's own call chain. Whatever goes
-- wrong here is contained: the wheel has already been populated, and the hook turns itself off.
function addon:OnWheelPopulate(wheel)
	local ok, err = pcall(function()
		if self.sv.menu == false or self.wheelBroken then
			return
		end

		local offers = self:CurrentOffers()
		if Count(offers) == 0 then
			return
		end

		-- the quickslot wheel only: the emote, memento, tool and ally wheels are left alone
		if wheel:GetHotbarCategory() ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
			return
		end

		if Try1(IsUnitInCombat, "player") then
			return
		end

		local names = Names()
		for _, kind in ipairs({ "paste", "move" }) do
			local list = offers[kind]
			if #list > 0 and #wheel.menu.entries < MAX_WHEEL_ENTRIES then
				local name = string.format("%s (%d)", names[kind], #list)
				local icon = ICONS[kind]
				wheel.menu:AddEntry(name, icon, icon, function()
					addon:PickedFromWheel(kind)
				end, { slotNum = self.wheelSlot, name = name, pbfe = kind })
			end
		end
	end)

	if not ok then
		self.wheelBroken = tostring(err)
		Print("the quickslot wheel extension stopped itself: %s", self.wheelBroken)
		Print("the wheel is the game's again; /pbfe reservations and /pbfe paste still work")
	end
end

-- ---------------------------------------------------------------------------------------
-- Picking an entry
-- ---------------------------------------------------------------------------------------

-- Does any offer of this kind want the point under the cursor?
local function UsesAim(offers)
	for _, offer in ipairs(offers) do
		for _, word in ipairs(offer.words or {}) do
			if word == "aim" then
				return true
			end
		end
	end
	return false
end

-- Called from inside the client's selection, so it only schedules. The one thing it does at once is
-- read where the cursor points: the camera is locked while the wheel is up and is let go of as the
-- button is released, and anything scheduled would run after the player may have moved it.
function addon:PickedFromWheel(kind)
	local aim, why
	local ok, err = pcall(function()
		local offers = self:CurrentOffers()[kind]
		if offers and UsesAim(offers) then
			aim, why = self:AimPoint()
		end
	end)
	if not ok then
		aim, why = nil, "an error: " .. tostring(err)
	end

	addon.Later(0, function()
		addon:RunOffers(kind, aim, why)
	end)
end

local function WithGo(words)
	local out, has = {}, false
	for _, word in ipairs(words or {}) do
		out[#out + 1] = word
		if word == "go" then
			has = true
		end
	end
	if not has then
		out[#out + 1] = "go"
	end
	return out
end

function addon:RunOffers(kind, aim, aimWhy)
	if self.run then
		Print("a %s is running -- /pbfe stop", self.run.kind)
		return
	end

	local offers = self:CurrentOffers()[kind]
	if #offers == 0 then
		Print("nothing to %s here any more", kind)
		return
	end

	Print("quickslot wheel: %s (%d)", Names()[kind], #offers)
	self.menuJobs = {}
	for _, offer in ipairs(offers) do
		self.menuJobs[#self.menuJobs + 1] = offer
	end
	self.menuAim, self.menuAimWhy = aim, aimWhy
	self:RunMenuJobs()
end

-- One offer after another; a run that ends (AfterRun) comes back here for the next. You are
-- standing where you chose, so "here" is this spot and "go" is the pick itself.
function addon:RunMenuJobs()
	if self.run then
		return
	end

	local offer = table.remove(self.menuJobs or {}, 1)
	if not offer then
		return self:MenuRefreshed()
	end

	-- the cursor point read at the pick is shared by everything that pick runs
	local meta = {}
	for key, value in pairs(offer.meta or {}) do
		meta[key] = value
	end
	meta.aim, meta.aimWhy = self.menuAim, self.menuAimWhy
	meta.aimFallback = true       -- a pick on the wheel pastes where you stand if the cursor cannot be read

	local outcome = self:Paste(WithGo(offer.words), false, offer.clip, meta)
	if outcome == "started" then
		if offer.source == "trip" and self.tripOffers then
			for index = #self.tripOffers, 1, -1 do
				if self.tripOffers[index] == offer.trip then
					table.remove(self.tripOffers, index)
				end
			end
		end
		return
	end

	-- not started (short of items, refused): it stays on offer, and the next one is tried
	return self:RunMenuJobs()
end

-- ---------------------------------------------------------------------------------------
-- Telling the player
-- ---------------------------------------------------------------------------------------

-- On arrival: what is on the wheel now. `arrival` is true when the player has just come into a house (or
-- logged in): a cut that is still held from an earlier visit is then said, with what to do about it, because
-- it refuses every new copy and cut and is easily forgotten.
function addon:AnnounceMenu(arrival)
	local held = self.sv.clip
	if arrival and held and held.cut and self.PrintCutAdvice then
		Print("a cut of %d furnishings is still held from an earlier visit:", #held.nodes)
		self:PrintCutAdvice(held)
	end

	local offers = self:CurrentOffers()
	if Count(offers) == 0 then
		return
	end

	if self.sv.menu == false then
		Print("%s waiting here (the wheel extension is off: /pbfe menu on)", Describe(offers))
		return
	end

	local ok, why = self:InstallWheelHook()
	if not ok then
		Print("the quickslot wheel could not be extended (%s)", why)
		Print("use /pbfe reservations run <n> go, or /pbfe paste")
		return
	end

	self.menuShown = true
	Print("quickslot wheel: %s. hold the quickslot button, point at it, let go", Describe(offers))
end

-- Called when a run ends, and when the player moves on: if there is nothing left, say so once.
-- onlyIfGone: say nothing unless the wheel has gone back to normal (arriving somewhere new).
function addon:MenuRefreshed(onlyIfGone)
	if not self.menuShown then
		return
	end

	local offers = self:CurrentOffers()
	if Count(offers) == 0 then
		self.menuShown = false
		Print("the quickslot wheel is back to normal")
	elseif not onlyIfGone then
		Print("still on the wheel: %s", Describe(offers))
	end
end

-- ---------------------------------------------------------------------------------------
-- /pbfe menu
-- ---------------------------------------------------------------------------------------

addon:AddCommand("menu", "  /pbfe menu [on|off]     Paste / Move on the quickslot wheel when something is waiting here", function(self, words)
	local what = words[1]

	if what == "off" then
		self.sv.menu = false
		Print("the wheel extension is off")
		self:MenuRefreshed()
		return
	elseif what == "on" then
		self.sv.menu = true
		self.wheelBroken = nil
		Print("the wheel extension is on")
		self:AnnounceMenu()
		return
	end

	local offers = self:CurrentOffers()
	Print("wheel extension: %s%s", self.sv.menu == false and "off" or "on",
		self.wheelBroken and (" -- stopped: " .. self.wheelBroken) or "")
	Print("hook: %s, borrowed slot: %s", self.wheelHooked and "installed" or "not installed", tostring(self.wheelSlot))
	if Count(offers) == 0 then
		Print("nothing is waiting in this house")
	else
		Print("on the wheel here: %s", Describe(offers))
	end
end)

addon:AddCommand("position", "  /pbfe position [aim|here|same]   where the quickslot wheel puts a paste (default aim)", function(self, words)
	local what = words[1]
	if what == "aim" or what == "here" or what == "same" then
		self.sv.pasteMode = what
		Print("the wheel now pastes: %s", what == "aim" and "where the cursor points (where you stand if it cannot be read)"
			or what == "here" and "where you stand" or "at the original coordinates")
		return
	end

	Print("the wheel pastes: %s. say /pbfe position aim, here or same", self.sv.pasteMode or "aim")
end)

