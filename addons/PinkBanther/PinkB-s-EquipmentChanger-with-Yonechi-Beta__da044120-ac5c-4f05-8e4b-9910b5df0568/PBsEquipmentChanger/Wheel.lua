-- An extra page on the utility wheel (hold D-pad up on a console), listing the saved sets.
--
-- ---------------------------------------------------------------------------------------
-- HOW THE PAGE GETS THERE WITHOUT TOUCHING THE CLIENT'S CODE
-- ---------------------------------------------------------------------------------------
--
-- Add-on Lua is insecure code. A client closure created while an add-on frame is on the stack is untrusted
-- for good, so wrapping a client function that builds a screen (ZO_PostHook, or replacing a method with a
-- function that calls the original) can poison the callbacks that function creates. The utility wheel's
-- PopulateMenu is exactly such a function: its entries call SetCurrentQuickslot, OnSlotUp and
-- PlayEmoteByIndex. Breaking those would break the player's quickslots.
--
-- So nothing here wraps PopulateMenu, ShowMenu, CycleLeft or CycleRight. Three things are done instead:
--
--   1. Five pure getters on the wheel object are replaced: the page index arithmetic and the lookups of
--      "which hotbar category is this page". They read a field and return a number; they create no closure
--      and call no game function, and the client's own CycleRight, CycleLeft and PopulateMenu keep running
--      in client frames and simply see one page more. The client keeps its list of pages in a local
--      table, so the page count is learned once by asking the original getter.
--
--   2. The extra page is, to the client, a stand-in category (the emote wheel when it exists), so the
--      client builds the page from client frames. SecurePostHook then runs after the client's PopulateMenu
--      and rewrites the entries it just made: plain data in a table the client reads next (name, icon,
--      callback). No wrapper is installed around the client's function. The same is done after
--      SetupEntryControl (to blank the stack count and cooldown the stand-in slot would have drawn) and
--      after RefreshCategories (the names of the neighbouring pages).
--
--   3. Choosing a set is the client's own selection: releasing D-pad up calls the entry's callback, which is
--      ours, and which calls only the game's public change calls (Apply.lua).
--
-- If SecurePostHook does not exist, the page is not installed at all. There is deliberately no fallback to
-- a Lua wrapper.

local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS

A.wheel = { installed = false, active = false, why = "not installed yet", errors = 0 }

local DEFAULT_ICON = "EsoUI/Art/Icons/icon_missing.dds"
local MAX_HOOK_ERRORS = 3

local function Raw(tbl, name)
	return type(tbl) == "table" and type(rawget(tbl, name)) == "function"
end

-- Run a hook body so that an error in it never reaches the client's wheel.
local function Guarded(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local w = A.wheel
		w.errors = w.errors + 1
		w.lastError = tostring(err)
		if w.errors >= MAX_HOOK_ERRORS then
			w.active = false
			w.why = "switched off after errors: " .. w.lastError
		end
	end
end

function A:InstallWheel()
	local w = self.wheel
	if w.installed then
		return true
	end
	w.attempts = (w.attempts or 0) + 1
	w.retryable = false
	local probe = self.sv.probe
	-- "bad" is written only after STRIKES_TO_DISABLE start-ups in a row that found the wheel's mark left over
	-- (Core.lua, Sanitize); a clean close of the wheel resets the count, the panel's retry button forgets it.
	if probe.wheel == "bad" then
		w.why = S.whyEarlier
		return false
	end

	local wheel, shared, gamepad = UTILITY_WHEEL_GAMEPAD, ZO_UtilityWheel_Shared, ZO_UtilityWheel_Gamepad
	if type(wheel) ~= "table" or type(shared) ~= "table" or type(gamepad) ~= "table" then
		w.why = "the client's utility wheel does not exist"
		w.retryable = true
		return false
	end
	if type(SecurePostHook) ~= "function" then
		w.why = "SecurePostHook does not exist"
		return false
	end
	for _, name in ipairs({ "PopulateMenu", "RefreshCategories", "PrepareForInteraction" }) do
		if not Raw(shared, name) then
			w.why = "ZO_UtilityWheel_Shared." .. name .. " is not as expected"
			return false
		end
	end
	for _, name in ipairs({ "SetupEntryControl", "StopInteraction" }) do
		if not Raw(gamepad, name) then
			w.why = "ZO_UtilityWheel_Gamepad." .. name .. " is not as expected"
			return false
		end
	end
	for _, name in ipairs({ "GetHotbarCategory", "GetNextHotbarCategoryIndex", "GetPreviousHotbarCategoryIndex", "GetNextHotbarCategory", "GetPreviousHotbarCategory" }) do
		if type(wheel[name]) ~= "function" then
			w.why = "the wheel's " .. name .. " is not as expected"
			return false
		end
	end
	if type(wheel.menu) ~= "table" or type(wheel.menu.entries) ~= "table" then
		w.why = "the wheel's radial menu is not as expected"
		w.retryable = true
		return false
	end

	-- The client's pages, learned by asking its own getter about a stand-in table that holds only the index.
	local getCategory = wheel.GetHotbarCategory
	local cats = {}
	for i = 1, 20 do
		local ok, cat = pcall(getCategory, { currentHotbarCategoryIndex = i })
		if not ok then
			w.why = "asking for the wheel's pages failed: " .. tostring(cat)
			return false
		end
		if cat == nil then
			break
		end
		cats[i] = cat
	end
	local count = #cats
	if count < 1 or count >= 20 then
		w.why = "the wheel has an unexpected number of pages: " .. tostring(count)
		return false
	end
	local ours = count + 1
	local standIn = cats[count]
	if type(HOTBAR_CATEGORY_EMOTE_WHEEL) == "number" then
		for _, cat in ipairs(cats) do
			if cat == HOTBAR_CATEGORY_EMOTE_WHEEL then
				standIn = cat
			end
		end
	end

	self.sv.pending = "wheel"
	local ok, err = pcall(function()
		local function pages()
			return (A.sv.wheel and w.active) and ours or count
		end
		local function categoryAt(index)
			if index == ours then
				return standIn
			end
			return cats[index]
		end

		-- 1. the pure getters
		-- (an index above pages() can only be left over from the moment the page was switched off)
		wheel.GetNextHotbarCategoryIndex = function(self)
			local index = self.currentHotbarCategoryIndex
			if index >= pages() then
				return 1
			end
			return index + 1
		end
		wheel.GetPreviousHotbarCategoryIndex = function(self)
			local index = self.currentHotbarCategoryIndex
			if index <= 1 or index > pages() then
				return pages()
			end
			return index - 1
		end
		wheel.GetHotbarCategory = function(self)
			return categoryAt(self.currentHotbarCategoryIndex)
		end
		wheel.GetNextHotbarCategory = function(self)
			return categoryAt(self:GetNextHotbarCategoryIndex())
		end
		wheel.GetPreviousHotbarCategory = function(self)
			return categoryAt(self:GetPreviousHotbarCategoryIndex())
		end

		local function onOurPage(self)
			return w.active and A.sv.wheel and self == wheel and self.currentHotbarCategoryIndex == ours
		end

		-- 2. data rewritten after the client has built the page
		SecurePostHook(shared, "PopulateMenu", function(self)
			if onOurPage(self) then
				Guarded(A.FillWheelPage, A, self)
			end
		end)
		SecurePostHook(shared, "RefreshCategories", function(self)
			if w.active and A.sv.wheel and self == wheel then
				Guarded(A.LabelWheelPages, A, self, ours)
			end
		end)
		SecurePostHook(gamepad, "SetupEntryControl", function(self, entryControl, data)
			if w.active and type(data) == "table" and data.pbec then
				Guarded(A.TouchWheelEntry, A, entryControl, data)
			end
		end)
		SecurePostHook(shared, "PrepareForInteraction", function(self)
			if w.active and A.sv.wheel and A.sv.wheelFirst and self == wheel then
				self.currentHotbarCategoryIndex = ours
			end
		end)
		-- The wheel closed without the client's error screen: forget the "in use" mark (see FillWheelPage) and
		-- the strikes against the page.
		SecurePostHook(gamepad, "StopInteraction", function(self)
			if A.sv.pending == "wheelUse" then
				A.sv.pending = nil
				A.sv.strikes.wheel = nil
			end
		end)
	end)
	self.sv.pending = nil
	if not ok then
		w.why = "installing failed: " .. tostring(err)
		-- some of it may have been installed; leave the page off
		return false
	end

	w.installed, w.active, w.why = true, true, "installed"
	w.pages, w.ours, w.standIn = count, ours, standIn
	probe.wheel = "ok"
	return true
end

-- After the player asked to forget what was learned: try to put the page in at once.
function A:RetryWheel()
	local w = self.wheel
	if not w.installed then
		self:InstallWheel()
		self:Print("wheel page: %s (%s)", w.installed and "on" or "off", w.why)
	end
end

-- The client's wheel may not exist yet at the first activation of a login; look again a little later (twice at
-- most per activation) when that is the only thing missing.
local RETRY_DELAYS_MS = { 5000, 20000 }

function A:ScheduleWheelRetry()
	local w = self.wheel
	if w.installed or not w.retryable or type(zo_callLater) ~= "function" then
		return
	end
	w.retryToken = (w.retryToken or 0) + 1
	local token = w.retryToken
	for _, delay in ipairs(RETRY_DELAYS_MS) do
		zo_callLater(function()
			if token == w.retryToken and not w.installed then
				self:InstallWheel()
			end
		end, delay)
	end
end

-- The page's entries: what the client built from the stand-in category, rewritten as the saved sets.
function A:FillWheelPage(wheel)
	local entries = wheel.menu and wheel.menu.entries
	if type(entries) ~= "table" then
		return
	end
	-- If the client's error screen ever follows this and the player reloads, the file still says "wheelUse":
	-- that is a strike against the page, and after two in a row it is not installed (Sanitize, InstallWheel).
	-- StopInteraction clears the mark and the strikes.
	self.sv.pending = "wheelUse"
	local emptyName = ZO_UTILITY_SLOT_EMPTY_STRING or ""
	local emptyIcon = ZO_UTILITY_SLOT_EMPTY_TEXTURE or DEFAULT_ICON
	for index, entry in ipairs(entries) do
		local set = self:GetSet(index)
		if set then
			local icon = set.icon or DEFAULT_ICON
			entry.name = set.name
			entry.inactiveIcon, entry.activeIcon = icon, icon
			entry.callback = function()
				A:Load(index, "wheel")
			end
			entry.data = { slotNum = index, name = set.name, pbec = true }
		else
			entry.name = emptyName
			entry.inactiveIcon, entry.activeIcon = emptyIcon, emptyIcon
			entry.callback = nil
			entry.data = { slotNum = index, name = "", pbec = true, empty = true }
		end
	end
end

-- The three names the wheel shows for pages: the current one in the middle, the neighbours at the bottom.
function A:LabelWheelPages(wheel, ours)
	local title = S.wheelTitle
	if wheel.currentHotbarCategoryIndex == ours and wheel.categoryLabel then
		wheel.categoryLabel:SetText(title)
	end
	if wheel:GetNextHotbarCategoryIndex() == ours and wheel.nextCategoryName then
		wheel.nextCategoryName:SetText(title)
	end
	if wheel:GetPreviousHotbarCategoryIndex() == ours and wheel.previousCategoryName then
		wheel.previousCategoryName:SetText(title)
	end
end

-- The client set the entry up for a slot of the stand-in category: take back what that would have drawn.
function A:TouchWheelEntry(entryControl, data)
	if entryControl.count then
		entryControl.count:SetHidden(true)
	end
	if entryControl.icon then
		entryControl.icon:SetDesaturation(0)
	end
	if entryControl.cooldown then
		entryControl.cooldown:ResetCooldown()
		entryControl.cooldown:SetHidden(true)
	end
	local label = entryControl.label
	if label then
		local keysShown = false
		if ZO_AreTogglableWheelsEnabled then
			local ok, value = pcall(ZO_AreTogglableWheelsEnabled)
			keysShown = ok and value == true
		end
		label:SetText(data.name or "")
		label:SetHidden(data.empty == true or keysShown)
	end
end

function A:WheelStatusLines()
	local w = self.wheel
	local lines = {}
	lines[#lines + 1] = string.format("wheel page: %s (%s)", (w.installed and w.active and self.sv.wheel) and "on" or "off", w.why)
	lines[#lines + 1] = string.format("wheel install attempts: %d; strikes against the page: %s (off at %d)", w.attempts or 0, tostring(self.sv.strikes.wheel or 0), self.STRIKES_TO_DISABLE)
	if w.installed then
		lines[#lines + 1] = string.format("wheel pages: %d from the client + this one as page %d; stand-in category %s", w.pages, w.ours, tostring(w.standIn))
	end
	if w.errors > 0 then
		lines[#lines + 1] = string.format("wheel errors: %d, last: %s", w.errors, tostring(w.lastError))
	end
	return lines
end
