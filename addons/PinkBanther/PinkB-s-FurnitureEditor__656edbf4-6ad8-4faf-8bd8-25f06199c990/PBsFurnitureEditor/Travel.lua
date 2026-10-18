-- PB's FurnitureEditor -- pasting into a house you are not standing in
--
-- A paste works on the house the player is in. "paste to 2" goes to the second house in
-- /pbfe houses first, and carries on when the player arrives:
--
--   RequestJumpToHouse(houseId, jumpOutside)       what the client's own travel dialog calls
--   EVENT_PLAYER_ACTIVATED                         the load screen is over
--
-- Three things about arriving decide how this is written:
--
--   * A house is not ready the moment the player is in it. Furnishings stream in, and the
--     ownership flag can read false for a moment, so a plan made too early plans against half a
--     house. The count of furnishings is watched until it stops changing.
--   * The player lands on the doorway, where the client refuses to place anything. A paste that
--     is "here" (relative to where you stand) is therefore shown, not performed, after a jump:
--     it waits for the player to walk to where the group goes. "same" (original coordinates)
--     does not depend on where you stand, so "paste to 2 same go" runs on its own.
--   * Add-on Lua survives a zone change (it is not a UI reload), so the half-finished command is
--     kept in memory. It is dropped if the player never arrives, or on /pbfe stop.

local addon = PBS_FURNITURE_EDITOR

local Call, Try1 = addon.Call, addon.Try1
local IdKey, IsNoId = addon.IdKey, addon.IsNoId
local Print, Line = addon.Print, addon.Line

local JUMP_TIMEOUT_MS = 120000
local FIRST_LOOK_MS = 2000
local LOOK_EVERY_MS = 1000
local MAX_LOOKS = 25
local STABLE_LOOKS = 2

-- ---------------------------------------------------------------------------------------
-- The houses the player owns
--
-- A house is a collectible of the house category; its reference id is the houseId. The same
-- list the client's own collections screen shows, narrowed to the ones that are unlocked.
-- ---------------------------------------------------------------------------------------

function addon:OwnedHouses()
	local list = {}

	local categoryType = COLLECTIBLE_CATEGORY_TYPE_HOUSE
	if categoryType == nil then
		return list
	end

	local total = Try1(GetTotalCollectiblesByCategoryType, categoryType) or 0
	local primary = Try1(GetHousingPrimaryHouse)

	for index = 1, total do
		local collectibleId = Try1(GetCollectibleIdFromType, categoryType, index)
		if collectibleId and Try1(IsCollectibleUnlocked, collectibleId) then
			local houseId = Try1(GetCollectibleReferenceId, collectibleId)
			if houseId and houseId ~= 0 then
				local nickname = Try1(GetCollectibleNickname, collectibleId)
				list[#list + 1] = {
					houseId = houseId,
					collectibleId = collectibleId,
					name = addon.Clean(Try1(GetCollectibleName, collectibleId)),
					nickname = (type(nickname) == "string" and nickname ~= "") and addon.Clean(nickname) or nil,
					primary = houseId == primary,
				}
			end
		end
	end

	-- a stable order, so that "to 2" means the same house every time
	table.sort(list, function(a, b) return a.houseId < b.houseId end)
	return list
end

local function HouseLabel(house)
	if house.nickname then
		return house.name .. " (" .. house.nickname .. ")"
	end
	return house.name
end

addon:AddCommand("houses", "  /pbfe houses            your houses, numbered; paste to <number> uses these", function(self)
	local houses = self:OwnedHouses()
	if #houses == 0 then
		Print("no houses found (or this build cannot list them)")
		return
	end

	local here = Try1(GetCurrentZoneHouseId) or 0
	Print("%d houses", #houses)
	for i, house in ipairs(houses) do
		Line("  #%d  %s  [id %d]%s%s", i, HouseLabel(house), house.houseId,
			house.primary and "  primary" or "", house.houseId == here and "  <- you are here" or "")
	end
end)

-- ---------------------------------------------------------------------------------------
-- Going there
-- ---------------------------------------------------------------------------------------

local function CountFurniture()
	local count = 0
	local id = Try1(GetNextPlacedHousingFurnitureId, nil)
	while id ~= nil and not IsNoId(id) and count < 20000 do
		count = count + 1
		id = Try1(GetNextPlacedHousingFurnitureId, id)
	end
	return count
end

function addon:PasteTo(opts, clip, meta)
	local houses = self:OwnedHouses()
	local target = houses[opts.to]
	if not target then
		Print("no house #%s -- /pbfe houses", tostring(opts.to))
		return
	end

	self:JumpAndPaste(target, opts.rest, opts.outside, clip, meta)
end

-- Go to `target` (an entry of OwnedHouses) and paste there on arrival. clip and meta are optional:
-- a reservation brings its own clip, and wants to be told how the paste ended.
function addon:JumpAndPaste(target, rest, outside, clip, meta)
	if self.jump then
		Print("a trip is already under way -- /pbfe stop")
		return
	end

	-- already there: this is just a paste, and the player has chosen where to stand
	if (Try1(GetCurrentZoneHouseId) or 0) == target.houseId then
		Print("you are already in %s", HouseLabel(target))
		return self:Paste(rest, false, clip, meta)
	end

	if Try1(CanJumpToHouseFromCurrentLocation) == false then
		local text = Try1(GetString, SI_COLLECTIONS_CANNOT_JUMP_TO_HOUSE_FROM_LOCATION)
		Print("%s", type(text) == "string" and text ~= "" and text or "cannot travel to a house from here")
		return
	end

	local jump = {
		houseId = target.houseId,
		name = HouseLabel(target),
		rest = rest,
		clip = clip,
		meta = meta,
		outside = outside and true or false,
	}
	self.jump = jump

	local results, err = Call(RequestJumpToHouse, target.houseId, jump.outside)
	if not results then
		self.jump = nil
		Print("the jump was refused: %s", tostring(err))
		return
	end

	Print("travelling to %s%s; the paste carries on when you arrive", jump.name, jump.outside and " (outside)" or "")

	addon.Later(JUMP_TIMEOUT_MS, function()
		if addon.jump == jump then
			addon.jump = nil
			Print("never arrived at %s; the trip is dropped", jump.name)
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- Arriving
-- ---------------------------------------------------------------------------------------

function addon:OnPlayerActivated()
	local houseId = Try1(GetCurrentZoneHouseId) or 0

	-- the wheel of the house we came from is not this house's: say so if it has gone back to normal
	if self.MenuRefreshed then
		self:MenuRefreshed(true)
	end

	local jump = self.jump
	if jump and not jump.arrived and houseId == jump.houseId then
		jump.arrived = true
		Print("arrived at %s; waiting for it to finish loading", jump.name)
		self:WaitForHouse(function() return addon.jump == jump end, function()
			addon:ResumeAfterJump(jump)
		end)
		return
	end

	-- not a trip of ours: a house we were reserved for? (Reserve.lua)
	if houseId ~= 0 and self.ReservationsArrived then
		self:ReservationsArrived(houseId)
	end
end

-- Wait until the number of furnishings has not changed for a couple of looks and the client says
-- the player owns the house; stop waiting (not the paste) after MAX_LOOKS. `valid` says whether
-- anyone still wants the answer; `done` is called when the house is ready.
function addon:WaitForHouse(valid, done)
	local looks, last, stable = 0, -1, 0

	local function look()
		if not valid() then
			return
		end

		looks = looks + 1
		local count = CountFurniture()
		if count == last then
			stable = stable + 1
		else
			stable = 0
		end
		last = count

		local owner = Try1(IsOwnerOfCurrentHouse) and true or false
		if (stable >= STABLE_LOOKS and owner) or looks >= MAX_LOOKS then
			if not owner then
				Print("the client has not said you own this house yet; going on anyway")
			end
			return done()
		end

		addon.Later(LOOK_EVERY_MS, look)
	end

	addon.Later(FIRST_LOOK_MS, look)
end

function addon:ResumeAfterJump(jump)
	if self.jump ~= jump then
		return
	end
	self.jump = nil

	if (Try1(GetCurrentZoneHouseId) or 0) ~= jump.houseId then
		Print("you left %s before the paste could start", jump.name)
		return
	end

	local clip = jump.clip or self.sv.clip
	local outcome = self:Paste(jump.rest, true, jump.clip, jump.meta)

	-- A paste that only showed its plan (it was not told to go, or "here" cannot start at the
	-- doorway) is offered on the quickslot wheel, for when the player has walked to the spot: the
	-- clipboard becomes fresh again, or, for a clip of its own, a trip offer.
	if outcome ~= "started" and clip and not jump.meta then
		if clip == self.sv.clip then
			self.sv.clipFresh = true
		elseif self.AddTripOffer then
			self:AddTripOffer(jump.houseId, clip, jump.rest)
		end
	end
	if self.AnnounceMenu then
		self:AnnounceMenu(true)
	end

	-- anything reserved for this house follows, once the paste (if there is one) has finished
	if self.EnqueueReservations then
		self:EnqueueReservations(jump.houseId)
	end
end

function addon:OnInitialise()
	EVENT_MANAGER:RegisterForEvent(self.name .. "Travel", EVENT_PLAYER_ACTIVATED, function()
		self:OnPlayerActivated()
	end)
end
