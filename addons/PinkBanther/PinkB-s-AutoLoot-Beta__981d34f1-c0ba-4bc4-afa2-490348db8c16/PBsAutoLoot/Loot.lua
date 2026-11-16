-- Taking everything when a loot window opens.
--
-- The client shows its loot window from its own EVENT_LOOT_UPDATED handler (loot_shared.lua). This add-on's handler
-- is registered after it, so it runs second and calls LootAll, which is what the window's "Take all" button calls
-- (LOOT_SHARED:LootAllItems -> LootAll(AreNonStolenItemsPresent())).
--
-- The one argument is `ignoreStolenItems`. The client passes "are there non-stolen items": taking only those when
-- there are some, and stealing when there is nothing else. This add-on passes true (leave stolen items) unless
-- TakeStolen() says they are to be taken, so a window that holds nothing but stolen items (a pickpocket, an owned
-- chest) is left open for the player to decide; when stolen items are to be taken it passes false and takes all.
--
-- WHETHER STOLEN ITEMS ARE TAKEN is decided by TakeStolen() from the one choice "stolenMode": "take" (always),
-- "leave" (never), or "game" (the default): the game's own loot settings decide:
--     "Auto Loot Stolen Items" (LOOT_SETTING_AUTO_LOOT_STOLEN): "If this option is off, auto-loot will not steal items;
--         they must be manually taken." -> off: leave them, on: take them.
--     "Prevent Stealing Placed Items" (LOOT_SETTING_PREVENT_STEALING_PLACED): the game stops the interaction with
--         placed items itself, so no loot window exists for them; this add-on also reads it as a veto: on -> never take
--         stolen items, whatever the other setting says.
-- The two are read when the add-on needs them for the first time, again after a loading screen, and again after the game
-- raises EVENT_INTERFACE_SETTING_CHANGED for the loot settings, so a loot window asks the game nothing. When the
-- game cannot be asked (the call is refused or raises) the add-on does not steal: not knowing is not permission.
--
-- Nothing is looked at in the window (no GetLootItemInfo, which returns a name and an icon string for every item):
-- the call itself is the whole job.
--
-- Guards against a loop:
--   * `busy`: LootAll changes the window, and the game may raise EVENT_LOOT_UPDATED again before the call returns;
--     that one is ignored.
--   * attempts: a window whose items cannot be taken (a full backpack, a unique item already owned) stays open and
--     is updated again. At most LOOT_MAX_ATTEMPTS calls are made per window; EVENT_LOOT_CLOSED (or a pause of
--     LOOT_QUIET_MS, in case that event is missed) starts a new count. EVENT_LOOT_ITEM_FAILED ends the attempts at
--     once: it says the game already tried and could not.

local A = PBS_AUTO_LOOT

A.lootState = {
	attempts = 0, -- LootAll calls made for the window that is open
	lastAt = 0, -- when the last one was made
	busy = false, -- inside a call
}
A.lootClosedAt = 0 -- when the last loot window closed (the box opener waits a little after it)

-- Read the game's two loot settings (A.game). GetSetting returns "0" / "1" as the client's own options panel reads it.
function A:ReadGameSettings()
	local g = self.game
	g.read = true
	g.stolen, g.prevent = nil, nil
	if not (SETTING_TYPE_LOOT and LOOT_SETTING_AUTO_LOOT_STOLEN and LOOT_SETTING_PREVENT_STEALING_PLACED) then
		return
	end
	local ok, value = self:Call("settings", "GetSetting", SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN)
	local number = ok and tonumber(value) or nil
	if number ~= nil then
		g.stolen = number ~= 0
	end
	ok, value = self:Call("settings", "GetSetting", SETTING_TYPE_LOOT, LOOT_SETTING_PREVENT_STEALING_PLACED)
	number = ok and tonumber(value) or nil
	if number ~= nil then
		g.prevent = number ~= 0
	end
end

-- Are stolen items taken now? Table reads only, once the settings have been read.
function A:TakeStolen()
	local mode = self.sv.stolenMode
	if mode == "take" then
		return true
	elseif mode == "leave" then
		return false
	end
	local g = self.game
	if not g.read then
		self:ReadGameSettings()
	end
	if g.stolen == nil or g.prevent == true then
		return false
	end
	return g.stolen
end

-- The game raised EVENT_INTERFACE_SETTING_CHANGED: read again next time, if it was a loot setting.
function A:OnSettingChanged(systemType)
	if SETTING_TYPE_LOOT ~= nil and systemType == SETTING_TYPE_LOOT then
		self.game.read = false
	end
end

function A:OnLootUpdated()
	local sv = self.sv
	if not sv then
		return
	end
	local now = GetGameTimeMilliseconds()
	-- with the option off the window is still ours for a few seconds after a box was used: opening a box and then
	-- leaving its contents in a window would be half a feature
	if not sv.loot and now >= self.boxLootUntil then
		return
	end
	local st = self.lootState
	local stats = self.stats
	-- a pause starts a new window; it also clears a `busy` that a call which died halfway left behind (a call takes
	-- no time at all, so "busy" for LOOT_QUIET_MS can only be a leftover)
	if now - st.lastAt > self.LOOT_QUIET_MS then
		st.attempts = 0
		st.busy = false
	end
	if st.busy then
		return
	end
	if st.attempts >= self.LOOT_MAX_ATTEMPTS then
		stats.lootGaveUp = stats.lootGaveUp + 1
		return
	end
	if st.attempts == 0 then
		stats.lootWindows = stats.lootWindows + 1
	end
	st.attempts = st.attempts + 1
	st.lastAt = now
	st.busy = true
	local ok = self:Call("loot", "LootAll", not self:TakeStolen())
	st.busy = false
	if ok then
		stats.lootCalls = stats.lootCalls + 1
	else
		stats.lootFailed = stats.lootFailed + 1
		-- a refused call is not worth repeating for this window
		st.attempts = self.LOOT_MAX_ATTEMPTS
	end
end

function A:OnLootClosed()
	local st = self.lootState
	st.attempts = 0
	st.busy = false
	self.lootClosedAt = GetGameTimeMilliseconds()
	-- a box that was waiting for the window to go can be opened now
	if self.boxQ:Count() > 0 or self.bindQ:Count() > 0 then
		self:Wake()
	end
end

function A:OnLootItemFailed()
	self.lootState.attempts = self.LOOT_MAX_ATTEMPTS
end

PBS_AL_MARK("Loot")
