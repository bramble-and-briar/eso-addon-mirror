-- Adding set pieces to the set collection.
--
-- The game adds a set piece to the player's set collection when the item becomes bound to them: at once for a piece
-- that binds on pickup, and for one that binds on equip (world drops, crafted and bought pieces) only when it is
-- worn. The tooltip says so: "Bind to add to your set collection." (SI_ITEM_FORMAT_STR_ADD_SET_COLLECTION_PIECE). The
-- inventory has a "Bind" action for exactly these items (inventoryslot.lua, TryBindItem -> BindItem), so a piece can
-- be collected without wearing it, and without touching the build the player is wearing. That is all this file does:
--
--     IsItemLockedSetPiece(bag, slot)   the piece is not in the collection yet (the "not collected" icon)
--     GetItemBindType == BIND_TYPE_ON_EQUIP and not IsItemBound   it would bind when worn
--     BindItem(bag, slot)               bind it now
--
-- Binding ends what the item could still be used for between players: a bound piece cannot be sold in the guild
-- store or traded. So by default:
--   * a piece the player has locked is left alone (locking is the way to say "not this one");
--   * a group drop that can still be traded (BoP and tradeable) is left alone (option collectTradeable);
--   * items that arrive while a bank is open (the player is taking them out, not finding them) are not queued;
--   * pieces already in the backpack at login are not bound unless the option says so; /pbal bind does it on demand.

local A = PBS_AUTO_LOOT

A.bind = { slot = nil, id = 0, at = 0 } -- the piece that was just bound and is being waited for

-- true when queued
function A:QueueBind(slot)
	local result = self.bindQ:Push(slot)
	if result == true then
		self.stats.queuedBinds = self.stats.queuedBinds + 1
		self:NotePeak()
		self:Wake()
		return true
	elseif result == nil then
		self.stats.dropped = self.stats.dropped + 1
	end
	return false
end

-- Queue every uncollected set piece in the backpack. Returns how many were added.
function A:SweepBinds()
	local added = 0
	for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
		if IsItemLockedSetPiece(BAG_BACKPACK, slot) and self:QueueBind(slot) then
			added = added + 1
		end
	end
	return added
end

-- nil when the slot holds a piece that may be bound, else a short reason. "tradeable" is the one that is counted
-- for the player (the piece is held back on purpose).
function A:BindProblem(slot)
	local sv = self.sv
	if not IsItemLockedSetPiece(BAG_BACKPACK, slot) then
		return "collected or not a set piece"
	end
	if sv.skipLocked and IsItemPlayerLocked and IsItemPlayerLocked(BAG_BACKPACK, slot) then
		return "locked"
	end
	if IsItemBound(BAG_BACKPACK, slot) then
		return "already bound"
	end
	if BIND_TYPE_ON_EQUIP ~= nil and GetItemBindType(BAG_BACKPACK, slot) == BIND_TYPE_ON_EQUIP then
		return nil
	end
	if IsItemBoPAndTradeable and IsItemBoPAndTradeable(BAG_BACKPACK, slot) then
		if sv.collectTradeable then
			return nil
		end
		return "tradeable"
	end
	return "does not bind on equip"
end

-- One look at the bind queue. Returns true while there is something left to do.
function A:StepBind(now)
	local sv = self.sv
	local stats = self.stats
	local b = self.bind
	local q = self.bindQ

	-- 1. a piece was bound: did it take?
	if b.slot then
		local slot = b.slot
		local count = GetSlotStackSize(BAG_BACKPACK, slot)
		if count == nil or count <= 0 then
			-- gone (moved, sold): nothing to count
			b.slot = nil
		elseif IsItemBound(BAG_BACKPACK, slot) or not IsItemLockedSetPiece(BAG_BACKPACK, slot) then
			b.slot = nil
			stats.bound = stats.bound + 1
			self:BatchAdd("bound", now)
			-- the link of the last piece of the batch: one field, overwritten by the next
			self.batch.link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_BRACKETS)
		elseif now - b.at >= self.BIND_CHECK_MS then
			b.slot = nil
			stats.bindFailed = stats.bindFailed + 1
			self:BatchAdd("bindFailed", now)
		else
			return true
		end
	end

	if q:Count() == 0 then
		self.manualBinds = false
		return false
	end
	-- the switch governs what arrives; a sweep that the player asked for runs whatever the switch says
	if not (sv.collect or self.manualBinds) then
		q:Clear()
		return false
	end
	local ready = self:Ready()
	if not ready then
		return true
	end

	-- 2. the next piece that can be bound (passing over at most a few that cannot, so a tick stays short)
	local slot
	for _ = 1, 8 do
		local candidate = q:Pop()
		if candidate == nil then
			break
		end
		local why = self:BindProblem(candidate)
		if not why then
			slot = candidate
			break
		end
		stats.bindSkipped = stats.bindSkipped + 1
		self.lastSkip = why
		if why == "tradeable" then
			self:BatchAdd("held", now)
		end
	end
	if not slot then
		return q:Count() > 0
	end

	b.at = now
	local ok, why = self:Call("bind", "BindItem", BAG_BACKPACK, slot)
	if ok then
		b.slot = slot
		return true
	end
	stats.bindFailed = stats.bindFailed + 1
	self.lastBindWhy = why
	if not self:Route("bind") then
		q:Clear()
		self:Notice("bindRefused", PBS_AUTO_LOOT_STRINGS.bindRefused, tostring(why))
		return false
	end
	self:BatchAdd("bindFailed", now)
	return q:Count() > 0
end

PBS_AL_MARK("Collect")
