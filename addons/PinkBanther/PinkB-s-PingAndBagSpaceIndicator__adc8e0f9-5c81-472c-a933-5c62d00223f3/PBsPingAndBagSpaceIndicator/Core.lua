-- PB's Ping & Bag Space Indicator
-- Author: PinkBanther
--
-- One small readout on the game screen: ping to the server, frame rate, used/free slots of the inventory and the
-- bank, and the gold the character carries.
--
-- ---------------------------------------------------------------------------------------
-- WHERE THE NUMBERS COME FROM (all public game functions, read once a second while the readout is up)
-- ---------------------------------------------------------------------------------------
--
--   ping       GetLatency()                          milliseconds
--   fps        GetFramerate()                        frames a second (a fraction; rounded here)
--   inventory  GetNumBagUsedSlots(BAG_BACKPACK) / GetBagSize(BAG_BACKPACK)
--              the same pair the game's own gamepad inventory header shows
--   bank       GetNumBagUsedSlots + GetBagUseableSize, summed over BAG_BANK and BAG_SUBSCRIBER_BANK
--              the way the game's own bank header adds them (the ESO Plus half is 0 without ESO Plus)
--   gold       GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER), and _BANK for the banked gold
--              (GetCurrentMoney / GetBankedMoney are PC-only compatibility aliases: not used)
--
-- Reading them is a handful of engine calls a second, and the label's text is only set when it changed, so
-- there is nothing to win by listening to inventory and money events instead.
--
-- Every reading is guarded: a function the client does not have, or one that raises, reads as "not known" and
-- is shown as a dash, never as an error.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS NOT KNOWN YET (nothing here has been run on a console)
-- ---------------------------------------------------------------------------------------
--
-- * Whether GetLatency and GetFramerate answer on a PS5 the way they do on a PC.
-- * Whether the bank's numbers are filled away from a bank (the client keeps the bank's contents loaded on a PC).
-- * Where on the console HUD the readout is out of the way of the game's own windows.
-- /pbping status prints the raw value of every function above, so one look answers the first two.
-- ---------------------------------------------------------------------------------------

PBS_PBSI = {
	name = "PBsPingAndBagSpaceIndicator",
	baseTitle = "PB’s Ping & Bag Space Indicator",
	chatName = "PB’s Ping & Bag Space",
	author = "PinkBanther",
	version = "0.1.0",
	slash = "/pbping",
	longSlash = "/pbpingandbagspace",
	savedVar = "PBsPingAndBagSpaceIndicator_Data",
	TICK_MS = 1000,
	-- Fonts are the named gamepad faces the console UI already has loaded (a face nothing else uses has to be
	-- built on use, and that crashed a PS5 once). padX/padY is the room the background leaves around the text.
	SIZES = {
		{ font = "ZoFontGamepad22", padX = 8, padY = 3 },
		{ font = "ZoFontGamepad27", padX = 10, padY = 4 },
		{ font = "ZoFontGamepad34", padX = 12, padY = 5 },
	},
	-- The corner (or edge middle) of the screen the readout is placed against. posX/posY move it from there:
	-- + is right / down, - is left / up.
	ANCHORS = { "TOPLEFT", "TOP", "TOPRIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
	LIMITS = {
		layout = { 1, 2 }, -- 1 one line, 2 one item a line
		bagMode = { 1, 2 }, -- 1 used / size, 2 free slots
		size = { 1, 3 },
		anchor = { 1, 6 },
		posX = { -960, 960 },
		posY = { -540, 540 },
		bgAlpha = { 0, 100 },
		pingWarn = { 20, 1000 },
		pingBad = { 20, 1000 },
		fpsWarn = { 5, 120 },
		fpsBad = { 5, 120 },
		bagWarn = { 0, 50 },
	},
	defaults = {
		enabled = true,
		showPing = true,
		showFps = true,
		showBag = true,
		showBank = true,
		showGold = true,
		showBankGold = false, -- not asked for, so off
		layout = 1,
		bagMode = 1,
		size = 2,
		anchor = 6, -- bottom right
		posX = -40,
		posY = -24,
		bgAlpha = 50,
		pingWarn = 200, -- ms from which the ping is yellow
		pingBad = 300, -- ms from which it is red
		fpsWarn = 45, -- fps below which the frame rate is yellow
		fpsBad = 25, -- below which it is red
		bagWarn = 10, -- free slots at or below which a bag is yellow (0 free is red)
	},
	-- The colours of the values, as |c markup.
	COLORS = {
		name = "B4B4B4",
		good = "66DD88",
		warn = "F0C846",
		bad = "F06450",
		plain = "FFFFFF",
		gold = "FFD75A",
	},
	GOLD_ICON = "|t100%:100%:EsoUI/Art/currency/gamepad/gp_gold.dds|t",
}
local A = PBS_PBSI
local S = PBS_PBSI_STRINGS

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[ \t\r\n]+$", "")
				A.version = plain:match("(%d+[%d%.]*)$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

A.errors = 0
A.lastError = nil

-- A handler that cannot raise: an error in an event handler would reach the game as an error screen.
function A.Guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			A.errors = A.errors + 1
			A.lastError = tostring(err)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands are the only text that is read: cut at ASCII blanks, lowered one ASCII letter at a time (a Lua
-- character class or lower() asks the C library, which answers by the locale).
-- ---------------------------------------------------------------------------------------

function A.LowerAscii(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

local function IsAsciiBlank(b)
	return b == 32 or (b >= 9 and b <= 13)
end

function A.SplitWords(input)
	input = tostring(input or "")
	local words, from = {}, nil
	for i = 1, #input + 1 do
		local b = input:byte(i)
		if b == nil or IsAsciiBlank(b) then
			if from then
				words[#words + 1] = input:sub(from, i - 1)
				from = nil
			end
		elseif not from then
			from = i
		end
	end
	return words
end

-- ---------------------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------------------

local function Clamp(value, limits, default)
	value = tonumber(value)
	if not value or value ~= value then
		return default
	end
	value = math.floor(value + 0.5)
	if value < limits[1] then
		return limits[1]
	elseif value > limits[2] then
		return limits[2]
	end
	return value
end

A.BOOLEANS = { "enabled", "showPing", "showFps", "showBag", "showBank", "showGold", "showBankGold" }

-- The red mark must not come before the yellow one: the threshold set last wins and pushes the other along.
function A:OrderThresholds(changed)
	local sv = self.sv
	if sv.pingBad < sv.pingWarn then
		if changed == "pingBad" then
			sv.pingWarn = sv.pingBad
		else
			sv.pingBad = sv.pingWarn
		end
	end
	if sv.fpsBad > sv.fpsWarn then
		if changed == "fpsBad" then
			sv.fpsWarn = sv.fpsBad
		else
			sv.fpsBad = sv.fpsWarn
		end
	end
end

-- Whatever is in the saved file (an older version, a hand edit) is brought back into range.
function A:Sanitize()
	local sv, defaults = self.sv, self.defaults
	for _, key in ipairs(self.BOOLEANS) do
		if type(sv[key]) ~= "boolean" then
			sv[key] = defaults[key]
		end
	end
	for key, limits in pairs(self.LIMITS) do
		sv[key] = Clamp(sv[key], limits, defaults[key])
	end
	self:OrderThresholds()
end

function A:Set(key, value)
	local limits = self.LIMITS[key]
	if limits then
		value = Clamp(value, limits, self.defaults[key])
	end
	self.sv[key] = value
	self:OrderThresholds(key)
end

-- Position and look back to the defaults (not which items are shown).
function A:ResetPlace()
	for _, key in ipairs({ "anchor", "posX", "posY", "size", "layout", "bgAlpha" }) do
		self.sv[key] = self.defaults[key]
	end
end

-- ---------------------------------------------------------------------------------------
-- Reading the game
-- ---------------------------------------------------------------------------------------

-- fn(...) when the function exists, answers without raising, and answers a number; else nil.
local function Number(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and type(value) == "number" and value == value then
		return value
	end
	return nil
end
A.Number = Number

-- Used and usable slots summed over the bags that exist; nil, nil when none answered.
local function Slots(bags, sizeFn)
	local used, size, any = 0, 0, false
	for _, bag in ipairs(bags) do
		if bag ~= nil then
			local u, s = Number(GetNumBagUsedSlots, bag), Number(sizeFn, bag)
			if u and s then
				used, size, any = used + u, size + s, true
			end
		end
	end
	if not any then
		return nil, nil
	end
	return used, size
end

-- Every number the readout can show, read now. A field is nil when the game did not answer it.
function A.Read()
	local r = {}
	r.ping = Number(GetLatency)
	local fps = Number(GetFramerate)
	r.fps = fps and math.floor(fps + 0.5) or nil
	r.bagUsed, r.bagSize = Slots({ BAG_BACKPACK }, GetBagSize)
	r.bankUsed, r.bankSize = Slots({ BAG_BANK, BAG_SUBSCRIBER_BANK }, GetBagUseableSize)
	if CURT_MONEY and CURRENCY_LOCATION_CHARACTER then
		r.gold = Number(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_CHARACTER)
	end
	if CURT_MONEY and CURRENCY_LOCATION_BANK then
		r.bankGold = Number(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_BANK)
	end
	return r
end

-- ---------------------------------------------------------------------------------------
-- The text
-- ---------------------------------------------------------------------------------------

local function Paint(hex, text)
	return "|c" .. hex .. text .. "|r"
end

-- 1234567 -> "1,234,567" (byte-wise; the game's own helper is not needed for digits).
function A.Group(n)
	local s = string.format("%d", n)
	local sign = ""
	if s:sub(1, 1) == "-" then
		sign, s = "-", s:sub(2)
	end
	local first = #s % 3
	if first == 0 then
		first = 3
	end
	local out = s:sub(1, first)
	for i = first + 1, #s, 3 do
		out = out .. "," .. s:sub(i, i + 2)
	end
	return sign .. out
end

function A:PingColor(ms)
	local sv = self.sv
	if ms >= sv.pingBad then
		return self.COLORS.bad
	elseif ms >= sv.pingWarn then
		return self.COLORS.warn
	end
	return self.COLORS.good
end

function A:FpsColor(fps)
	local sv = self.sv
	if fps < sv.fpsBad then
		return self.COLORS.bad
	elseif fps < sv.fpsWarn then
		return self.COLORS.warn
	end
	return self.COLORS.good
end

function A:FreeColor(free)
	if free <= 0 then
		return self.COLORS.bad
	elseif free <= self.sv.bagWarn then
		return self.COLORS.warn
	end
	return self.COLORS.plain
end

-- "123/200" or "77 free", coloured by the free slots.
function A:SlotsText(used, size)
	if not (used and size) then
		return Paint(self.COLORS.plain, S.unknown)
	end
	local free = size - used
	if free < 0 then
		free = 0
	end
	local text
	if self.sv.bagMode == 2 then
		text = string.format(S.freeFormat, free)
	else
		text = string.format("%d/%d", used, size)
	end
	return Paint(self:FreeColor(free), text)
end

function A:GoldText(amount)
	if not amount then
		return Paint(self.COLORS.gold, S.unknown)
	end
	return Paint(self.COLORS.gold, A.Group(amount)) .. " " .. self.GOLD_ICON
end

-- The readout's text for a reading: the items that are switched on, in a fixed order, one line or one a line.
function A:Compose(r)
	local sv, C = self.sv, self.COLORS
	local items = {}
	local function add(name, value)
		if name and name ~= "" then
			items[#items + 1] = Paint(C.name, name) .. " " .. value
		else
			items[#items + 1] = value
		end
	end
	if sv.showPing then
		add(S.ping, r.ping and Paint(self:PingColor(r.ping), string.format(S.msFormat, r.ping)) or Paint(C.plain, S.unknown))
	end
	if sv.showFps then
		add(S.fps, r.fps and Paint(self:FpsColor(r.fps), string.format("%d", r.fps)) or Paint(C.plain, S.unknown))
	end
	if sv.showBag then
		add(S.bag, self:SlotsText(r.bagUsed, r.bagSize))
	end
	if sv.showBank then
		add(S.bank, self:SlotsText(r.bankUsed, r.bankSize))
	end
	if sv.showGold then
		add(S.gold, self:GoldText(r.gold))
	end
	if sv.showBankGold then
		add(S.bankGold, self:GoldText(r.bankGold))
	end
	return table.concat(items, sv.layout == 2 and "\n" or "   ")
end

PBS_PBSI_MARK("Core")
