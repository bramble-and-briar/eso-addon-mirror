-- The markers themselves: who is marked with what, putting one on, taking one off, and the group roster they hang on.
--
-- A marker belongs to a PERSON, named by the hash of their @account name (A.Hash), not to a unit tag: the group's unit
-- tags are renumbered when somebody leaves, and each client numbers them for itself, while the name is the same
-- everywhere. The roster turns a hash into the tag it is under on THIS client right now.
--
--   marks[hash] = { name, icon, mine, owner, at, orphanSince, engine, engineSince }
--     mine   this player put it on (so this player sends it again every little while, see Share.lua)
--     owner  who put it on (a @name), for /pbpme status
--     at     when it was put on, or last heard (a marker from somebody else that is not heard again for TTL_MS is dropped:
--            its owner left, lost the connection, or the group was not told that it was taken off)
--     engine the game's own marker that was on this person when this one was put on (NONE if none), and
--     engineSince  since when that same one has stood next to this one: see ReconcileEngine
-- World.lua also keeps the frame's relative position (rel), the drawing verdict and its trace time on this marker.
--
-- One marker at a time on a person: putting the same icon on again takes it off (the way the game's own marker toggles),
-- another icon replaces it, and so does one of the game's eight -- whoever put that one on (see ReconcileEngine).
--
-- A marker goes with its person: a member who is not in the group (any more) or is OFFLINE loses it. The game keeps a
-- member who logged out in the group (client source: the group list and the map both ask IsUnitOnline), so being in the
-- roster is not enough.
local A, S = PBS_PME, PBS_PME_STRINGS
local em = EVENT_MANAGER

local ROSTER_MS = 1000 -- the roster is read at most this often unless something says the group changed
local TTL_MS = 75000 -- a marker of somebody else's that was not heard again for this long is dropped
local ORPHAN_MS = 10000 -- a marked person who has not been here (in the group and online) this long loses the marker
local ENGINE_CHECK_MS = 1000 -- after taking the game's marker off: read back whether it is gone
local ENGINE_GRACE_MS = 3000 -- an extra marker and an older game marker of the same person may stand together this long

A.marks = {}
A.roster = { list = {}, byHash = {}, at = -1e9, dirty = true }
A.stats = { placed = 0, taken = 0, refused = 0, remoteSet = 0, remoteClear = 0, expired = 0, orphaned = 0, engineWon = 0 }

local function NoneType()
	return TARGET_MARKER_TYPE_NONE or 0
end

function A:OwnName()
	local name = GetDisplayName and GetDisplayName() or nil
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

function A:Grouped()
	return GetGroupSize and GetGroupSize() > 1
end

-- ---------------------------------------------------------------------------------------
-- The roster: the people in the group, by hash
-- ---------------------------------------------------------------------------------------

function A:RosterDirty()
	self.roster.dirty = true
	if self.frames then
		self.frames.dirty = true
	end
end

function A:RefreshRoster(force)
	local r = self.roster
	local now = A.Stamp()
	if not (force or r.dirty) and now - r.at < ROSTER_MS then
		return r
	end
	r.at, r.dirty = now, false
	local before = r.byHash
	local list, byHash = {}, {}
	local size = GetGroupSize and GetGroupSize() or 0
	if r.size ~= size then
		-- (a group the game reads as "no group" for a moment is one way markers could go: this line shows it)
		if r.size ~= nil then
			self:Trace("roster", string.format("the game reports %d group members (was %d)", size, r.size))
		end
		r.size = size
	end
	if size > 1 and GetGroupUnitTagByIndex then
		for i = 1, size do
			local tag = GetGroupUnitTagByIndex(i)
			local name = tag and GetUnitDisplayName(tag)
			if type(name) == "string" and name ~= "" then
				local hash = A.Hash(name)
				if byHash[hash] then
					self:Trace("roster", "two members have the same marker id (" .. name .. "): the second one cannot be marked")
				else
					local isSelf = AreUnitsEqual(tag, "player") and true or false
					-- (a member who logged out stays in the group, offline; a call that is not allowed counts as "online")
					local online = isSelf or self:Call("IsUnitOnline", tag) ~= false
					local was = before[hash]
					if was and was.online ~= online then
						-- (a marker that disappears for this reason is explained by this line)
						self:Trace("roster", name .. (online and " is online again" or " went offline"))
					end
					-- the person's entry of the last reading is filled in again: the roster is read every second while anything is
					-- marked, and a new table per member each time was the add-on's steadiest garbage after the tick's closures
					local entry = was or {}
					entry.tag, entry.name, entry.hash, entry.self, entry.online = tag, name, hash, isSelf, online
					list[#list + 1] = entry
					byHash[hash] = entry
				end
			end
		end
	end
	-- Alone, the player can still mark themself: the roster is then just the player (a group is not needed for that; nothing
	-- is sent, there is nobody to send to).
	if #list == 0 then
		local own = self:OwnName()
		if own then
			local hash = A.Hash(own)
			local entry = before[hash] or {}
			entry.tag, entry.name, entry.hash, entry.self, entry.online = "player", own, hash, true, true
			list[1] = entry
			byHash[hash] = entry
		end
	end
	r.list, r.byHash = list, byHash
	return r
end

function A:OwnHash()
	local own = self:OwnName()
	return own and A.Hash(own) or nil
end

-- Leaving the group: the group's markers go; a marker this player put on themself stays (it is theirs alone).
function A:KeepOnlyOwnMark()
	local ownHash = self:OwnHash()
	local keep = ownHash and self.marks[ownHash]
	self.marks = {}
	if keep and keep.mine then
		self.marks[ownHash] = keep
	end
end

-- The group member under the reticle: entry, or nil and why (and the name of the message to show).
function A:ReticleMember()
	if not (DoesUnitExist and DoesUnitExist("reticleover")) then
		return nil, "nothing under the reticle", "notMember"
	end
	local r = self:RefreshRoster(true)
	if #r.list == 0 then
		return nil, "not in a group", "notInGroup"
	end
	for _, entry in ipairs(r.list) do
		if not entry.self and AreUnitsEqual("reticleover", entry.tag) then
			return entry
		end
	end
	return nil, "the unit under the reticle is not in the group", "notMember"
end

-- This player's own roster entry (alone: the one entry there is).
function A:SelfMember()
	for _, entry in ipairs(self:RefreshRoster(true).list) do
		if entry.self then
			return entry
		end
	end
	return nil
end

-- Who a pick on the wheel acts on: the group member under the reticle; or, with "mark myself" on and NOTHING under the
-- reticle (the game cannot aim the reticle at yourself), this player. An enemy or a stranger under the reticle is never
-- turned into "myself": that would put a marker on the wrong person by a slip of the aim.
-- Returns entry, nil, nil, onSelf   or   nil, why, message.
function A:PickTarget()
	local entry, why, message = self:ReticleMember()
	if entry then
		return entry, nil, nil, false
	end
	if self.sv.markSelf and not (DoesUnitExist and DoesUnitExist("reticleover")) then
		local own = self:SelfMember()
		if own then
			return own, nil, nil, true
		end
		return nil, "not in a group", "notInGroup"
	end
	-- (with "mark myself" on, the way to the player is to look at nothing: the message says so)
	if message == "notMember" and self.sv.markSelf then
		message = "notMemberSelf"
	end
	return nil, why, message
end

-- ---------------------------------------------------------------------------------------
-- The table
-- ---------------------------------------------------------------------------------------

-- The game's own marker on a person now (NONE when there is none, or when the game's call is not there).
function A:EngineMarkerOf(entry)
	if not GetUnitTargetMarkerType then
		return NoneType()
	end
	local markerType = GetUnitTargetMarkerType(entry.tag)
	return type(markerType) == "number" and markerType or NoneType()
end

function A:SetMark(hash, name, icon, mine, owner)
	local m = self.marks[hash]
	local fresh = not m or m.icon ~= icon
	if not m then
		m = {}
		self.marks[hash] = m
	end
	m.name, m.icon, m.mine, m.owner, m.at, m.orphanSince = name, icon, mine and true or false, owner, A.Stamp(), nil
	if self.frames then
		self.frames.dirty = true -- the group frames are looked at again at once
	end
	if fresh then
		-- a new marker (a repeat of the same one is not new): whatever game marker stands on the person now is the OLDER one
		local entry = self.roster.byHash[hash]
		m.engine = entry and self:EngineMarkerOf(entry) or NoneType()
		m.engineSince = nil
	end
	return m
end

function A:RemoveMark(hash, why)
	local m = self.marks[hash]
	if not m then
		return false
	end
	self.marks[hash] = nil
	if self.frames then
		self.frames.dirty = true
	end
	self:Trace("mark", string.format("%s: marker %s off (%s)", tostring(m.name), tostring(m.icon), why or "removed"))
	return true
end

function A:HasMine()
	for _, m in pairs(self.marks) do
		if m.mine then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------------------------------
-- Putting one on, taking one off (what the wheel asks for)
-- ---------------------------------------------------------------------------------------

-- With an empty reticle the standard wheel acts on the player, including when solo.
local function IsMarkerTarget(tag)
	local aimed = DoesUnitExist("reticleover")
	if tag == "player" then
		return not aimed
	end
	return aimed and (tag == "reticleover" or AreUnitsEqual("reticleover", tag))
end

-- Use the same toggle as the standard wheel while the selection still identifies its target.
function A:TakeEngineMarkerOff(tag, hash)
	if not GetUnitTargetMarkerType or not IsMarkerTarget(tag) then
		return
	end
	local current = GetUnitTargetMarkerType(tag)
	if type(current) ~= "number" or current == NoneType() then
		return
	end
	local name = GetUnitDisplayName(tag)
	local pending = self.engineCheck
	if pending and pending.tag == tag and pending.name == name and pending.before == current then
		-- The user changed icons before ESO acknowledged the toggle. Sending it twice can put the standard marker back.
		pending.hash, pending.mark = hash, self.marks[hash]
		return
	end
	local now = A.Stamp()
	self.engineCheck = { tag = tag, name = name, before = current, due = now + ENGINE_CHECK_MS,
		hash = hash, mark = self.marks[hash] }
	self:Trace("engine", string.format("reselected standard marker %d on %s", current, tag))
	self:Call("AssignTargetMarkerToReticleTarget", current)
	self:CheckEngineClear(now)
end

-- Some clients also accept NONE. Try it once if the old marker is still on the same
-- target after a second. A failed attempt never disables future wheel selections.
function A:CheckEngineClear(now)
	local check = self.engineCheck
	if not check then
		return
	end
	if not IsMarkerTarget(check.tag) or GetUnitDisplayName(check.tag) ~= check.name
		or (check.mark and (self.marks[check.hash] ~= check.mark or not check.mark.mine)) then
		self.engineCheck = nil
		return
	end
	local after = GetUnitTargetMarkerType(check.tag)
	if after == NoneType() then
		self.engineClearResult = check.fallback and "removed by assigning NONE" or "removed by reselecting the same marker"
	elseif after ~= check.before then
		self.engineCheck = nil -- another standard marker superseded this request
		return
	elseif now < check.due then
		return
	elseif not check.fallback then
		check.fallback = true
		check.due = now + ENGINE_CHECK_MS
		self:Call("AssignTargetMarkerToReticleTarget", NoneType())
		return
	else
		self.engineClearResult = "standard marker still present after both attempts"
	end
	self.engineCheck = nil
	self:Trace("engine", self.engineClearResult .. " on " .. check.tag)
end

-- ONE MARKER AT A TIME, the game's eight included, whoever puts which one on. The game's marker cannot be hidden by an
-- add-on, so when both stand on a person the extra one has to go -- unless it is the newer one, in which case the game's
-- is taken off (by the member who put the extra one on, PlaceExtended; the game shows that to everybody). Which is newer
-- is read from what this client saw: `engine` is the game's marker that stood on the person when the extra one came.
--   * a game marker that is not that one (put on later, or another type): it is newer: the extra marker goes at once;
--   * the same one still there: it is older and is being taken off: the extra marker may stand beside it for
--     ENGINE_GRACE_MS, and goes if the game's marker is still there then (it could not be taken off).
-- Every client reaches the same answer by itself (the game's markers are the group's), so nothing is sent for it except
-- by the member whose marker it was: they tell the group it is off.
function A:ReconcileEngine(now)
	if not GetUnitTargetMarkerType then
		return
	end
	local none = NoneType()
	for hash, m in pairs(self.marks) do
		local entry = self.roster.byHash[hash]
		if entry and entry.online then
			local engine = self:EngineMarkerOf(entry)
			if engine == none then
				m.engine, m.engineSince = none, nil
			elseif engine ~= m.engine then
				self:EngineWins(hash, m, entry, false)
			else
				m.engineSince = m.engineSince or now
				if now - m.engineSince >= ENGINE_GRACE_MS then
					self:EngineWins(hash, m, entry, true)
				end
			end
		end
	end
end

-- The game's marker stays, the extra one goes. `stuck`: it was the older one and could not be taken off.
function A:EngineWins(hash, m, entry, stuck)
	local mine = m.mine
	self.stats.engineWon = self.stats.engineWon + 1
	self:RemoveMark(hash, stuck and "the game's marker stands on this person and could not be taken off"
		or "the game's own marker was put on this person")
	if mine then
		self:ShareSend("CLEAR", hash, 0)
		self.stats.taken = self.stats.taken + 1
		self:Print(S[stuck and "engineStays" or "engineWon"], entry.name)
		self:Sound(stuck and "GENERAL_ALERT_ERROR" or "NEGATIVE_CLICK")
	end
end

-- The game says its markers changed (EVENT_TARGET_MARKER_UPDATE: it has no payload).
function A:OnEngineMarkersChanged()
	self:CheckEngineClear(A.Stamp())
	if next(self.marks) ~= nil then
		self:ReconcileEngine(A.Stamp())
	end
end

-- A member logged in or out (they stay in the group while offline).
function A:OnMemberOnline()
	self:RosterDirty()
end

-- Registers for what the group and the game's markers do; called once at start-up.
function A:StartMarks()
	em:RegisterForEvent(self.name .. "Reticle", EVENT_RETICLE_TARGET_CHANGED, function()
		self.engineCheck = nil
	end)
	em:RegisterForEvent(self.name .. "Online", EVENT_GROUP_MEMBER_CONNECTED_STATUS, function()
		self:OnMemberOnline()
	end)
	em:RegisterForEvent(self.name .. "EngineMarkers", EVENT_TARGET_MARKER_UPDATE, function()
		-- (a failure in here must not reach the game's own code)
		local ok, err = pcall(self.OnEngineMarkersChanged, self)
		if not ok then
			self.diag.lastError = "game marker event: " .. tostring(err)
			self.diag.errors = self.diag.errors + 1
		end
	end)
end

-- An extra marker was picked on the wheel.
function A:PlaceExtended(icon)
	if not A.IsIcon(icon) then
		return false
	end
	local entry, why, message, onSelf = self:PickTarget()
	if not entry then
		self.stats.refused = self.stats.refused + 1
		self:Trace("place", "refused: " .. tostring(why))
		self:Print(S[message or "notMember"])
		self:Sound("GENERAL_ALERT_ERROR")
		return false
	end
	local current = self.marks[entry.hash]
	if current and current.icon == icon then
		self.engineCheck = nil
		self:RemoveMark(entry.hash, "the same icon again")
		self:ShareSend("CLEAR", entry.hash, 0)
		self.stats.taken = self.stats.taken + 1
		self:Print(S.taken, entry.name)
		self:Sound("NEGATIVE_CLICK")
		return true
	end
	self:SetMark(entry.hash, entry.name, icon, true, self:OwnName())
	self.stats.placed = self.stats.placed + 1
	self:Trace("place", string.format("%s: marker %d (%s)", entry.name, icon, A.IconName(icon)))
	self:ShareSend("SET", entry.hash, icon)
	self:ShareArm()
	self:Print(S.placed, entry.name, A.IconName(icon))
	self:Sound("ABILITY_SLOTTED")
	self:TakeEngineMarkerOff(onSelf and "player" or entry.tag, entry.hash)
	return true
end

-- The wheel's "clear" entry: our marker on the group member under the reticle (or on this player, when nothing is under
-- it), and the game's own marker on whatever is under the reticle (a group member or not).
function A:ClearReticle()
	local entry, _, _, onSelf = self:PickTarget()
	if entry then
		if self.marks[entry.hash] then
			self:RemoveMark(entry.hash, "cleared on the wheel")
			self:ShareSend("CLEAR", entry.hash, 0)
			self.stats.taken = self.stats.taken + 1
			self:Print(S.taken, entry.name)
			self:Sound("NEGATIVE_CLICK")
		end
		self:TakeEngineMarkerOff(onSelf and "player" or entry.tag, entry.hash)
	elseif DoesUnitExist and DoesUnitExist("reticleover") then
		self:TakeEngineMarkerOff("reticleover", nil)
	end
	return true
end

-- One of the game's own eight is about to go on the unit under the reticle: if that is a group member with an extra
-- marker, the extra one goes (one marker at a time on a person).
function A:OnStandardAssign()
	if next(self.marks) == nil then
		return
	end
	local entry
	if DoesUnitExist("reticleover") then
		entry = self:ReticleMember()
	else
		entry = self:SelfMember()
	end
	if entry and self.marks[entry.hash] then
		self:RemoveMark(entry.hash, "the game's own marker was put on")
		self:ShareSend("CLEAR", entry.hash, 0)
	end
end

function A:ActClearAll()
	local had = next(self.marks) ~= nil
	self.marks = {}
	if had then
		self:ShareSend("CLEARALL", 0, 0)
		self:Trace("mark", "all markers taken off")
	end
	self:Print(S.cleared)
end

-- ---------------------------------------------------------------------------------------
-- What the group tells us (Share.lua calls these)
-- ---------------------------------------------------------------------------------------

function A:RemoteSet(sender, hash, icon)
	if not A.IsIcon(icon) then
		return false
	end
	local entry = self.roster.byHash[hash] or self:RefreshRoster(true).byHash[hash]
	if entry and not entry.online then
		-- (the sender's own copy of it, or a repeat that was already on its way, for somebody who has logged out)
		return false
	end
	local was = self.marks[hash]
	self:SetMark(hash, entry and entry.name or "?", icon, false, sender)
	self.stats.remoteSet = self.stats.remoteSet + 1
	if not was or was.icon ~= icon then
		self:Trace("heard", string.format("%s put marker %d on %s", sender, icon, entry and entry.name or "somebody"))
	end
	return true
end

function A:RemoteClear(sender, hash)
	if self:RemoveMark(hash, "taken off by " .. sender) then
		self.stats.remoteClear = self.stats.remoteClear + 1
	end
end

function A:RemoteClearAll(sender)
	if next(self.marks) ~= nil then
		self.marks = {}
		self.stats.remoteClear = self.stats.remoteClear + 1
		self:Trace("heard", sender .. " took all markers off")
	end
end

-- ---------------------------------------------------------------------------------------
-- Housekeeping (a few times a second)
-- ---------------------------------------------------------------------------------------

function A:Housekeeping(now)
	-- nothing marked and nothing to read back: nothing to do (the roster is read when somebody needs it)
	if next(self.marks) == nil and not self.engineCheck then
		return
	end
	local roster = self:RefreshRoster(false)
	if next(self.marks) ~= nil then
		if #roster.list == 0 then
			self.marks = {}
			self:Trace("mark", "all markers dropped: nobody to put them on")
		else
			local grouped, ownHash = self:Grouped(), self:OwnHash()
			for hash, m in pairs(self.marks) do
				if not grouped and hash ~= ownHash then
					-- alone: only a marker on the player themself can stay. Not drawn at once (the roster is just the player), but the
					-- markers go only after the same grace as a person who has left: a group the game reads as "no group" for a moment
					-- (a loading screen, a zone change) must not wipe what the group put on, and nothing would bring it back until the
					-- owners' next repeat. Leaving the group for real is an event of its own (KeepOnlyOwnMark).
					m.orphanSince = m.orphanSince or now
					if now - m.orphanSince > ORPHAN_MS then
						self.stats.orphaned = self.stats.orphaned + 1
						self:RemoveMark(hash, "not in a group")
					end
				elseif roster.byHash[hash] and roster.byHash[hash].online then
					m.orphanSince = nil
					if m.name == "?" then
						m.name = roster.byHash[hash].name
					end
				else
					-- not in the group, or in it but logged out: not drawn at once (World.lua); the marker goes after a
					-- while (a dropped connection that comes back in seconds keeps it)
					m.orphanSince = m.orphanSince or now
					if now - m.orphanSince > ORPHAN_MS then
						self.stats.orphaned = self.stats.orphaned + 1
						self:RemoveMark(hash, roster.byHash[hash] and "that person is offline" or "that person is not in the group")
					end
				end
				if not m.mine and self.marks[hash] and now - m.at > TTL_MS then
					self.stats.expired = self.stats.expired + 1
					self:RemoveMark(hash, "not heard again for " .. (TTL_MS / 1000) .. " s")
				end
			end
		end
	end
	if next(self.marks) ~= nil then
		self:ReconcileEngine(now)
	end
	self:CheckEngineClear(now)
end

A.MARK("Marks")
