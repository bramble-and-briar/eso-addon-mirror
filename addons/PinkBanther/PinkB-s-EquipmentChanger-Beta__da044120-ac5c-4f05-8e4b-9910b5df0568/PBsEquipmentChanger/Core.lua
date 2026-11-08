-- PB's Equipment Changer
-- Author: PinkBanther
--
-- Saves what a character wears and which skills sit on both action bars under a name, and puts them back
-- on request: from the settings panel, from the slash commands, or from an extra page of the utility wheel
-- (the wheel that opens when D-pad up is held on a console).
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS STORED, AND WHY IT IS STORED THIS WAY
-- ---------------------------------------------------------------------------------------
--
-- Gear: for each worn slot the item's unique id (as a string; an id64 cannot be written to a saved-variables
-- file), its link, name and icon. The unique id follows the item between the backpack and the worn bag,
-- so an item is found again wherever it sits in the backpack. Poisons are stacks whose id changes when the
-- stack merges, so those two slots match by link instead.
--
-- Skills: for each slot of the two weapon bars the action type and the id GetSlotBoundId returns. That id is
-- the *effective* ability (what the bar really shows); the request that slots a skill wants the skill's
-- current progression id, so Apply.lua translates one into the other through the client's skills data.
--
-- Champion points: the stars slotted on the champion bar (the champion skill id of each bar slot). Spending
-- points is not touched.
--
-- Two things are recorded only to warn at load time, because the add-on cannot change them from the HUD:
-- the morph a skill had (`pid`, the progression's ability id: another morph needs a skill respec at a
-- shrine, for gold) and the scribing scripts of a crafted ability (`scripts`: changing them is a RequestScribe
-- at the scribing altar, for ink).
--
-- Everything is kept per character, because items and class skills belong to one.

PBS_EQUIPMENT_CHANGER = {
	name = "PBsEquipmentChanger",
	baseTitle = "PB’s Equipment Changer",
	chatName = "PB’s Equipment Changer",
	author = "PinkBanther",
	version = "0.3.0",
	slash = "/pbequip",
	shortSlash = "/pbec",
	NUM_SLOTS = 8, -- the size of one wheel page (ACTION_BAR_UTILITY_BAR_SIZE)
	defaults = {
		wheel = true, -- the extra page on the utility wheel
		wheelFirst = false, -- open the wheel on that page
		saveGear = true, -- what "save" records
		saveSkills = true,
		saveChampion = true,
		applyGear = true, -- what "load" puts back
		applySkills = true,
		applyChampion = true,
		clearSkills = true, -- a slot that was empty when saved empties the bar slot (skill bars and champion bar)
		unequipEmpty = false, -- a gear slot that was empty when saved is emptied
		slot = 1, -- the slot the settings panel is working on
	},
}
local A = PBS_EQUIPMENT_CHANGER
local S = PBS_EQUIPMENT_CHANGER_STRINGS

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
				A.version = plain:match("(%d+[%d%.]*)%s*$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

-- Worn slots in the order they are put back: weapons first, a main hand before its off hand (a two-handed
-- weapon is replaced before the shield that goes with the next one), then poisons, armour, jewellery.
A.GEAR = {
	{ key = "mainHand", const = "EQUIP_SLOT_MAIN_HAND" },
	{ key = "offHand", const = "EQUIP_SLOT_OFF_HAND" },
	{ key = "backupMain", const = "EQUIP_SLOT_BACKUP_MAIN" },
	{ key = "backupOff", const = "EQUIP_SLOT_BACKUP_OFF" },
	{ key = "poison", const = "EQUIP_SLOT_POISON", byLink = true },
	{ key = "backupPoison", const = "EQUIP_SLOT_BACKUP_POISON", byLink = true },
	{ key = "head", const = "EQUIP_SLOT_HEAD" },
	{ key = "shoulders", const = "EQUIP_SLOT_SHOULDERS" },
	{ key = "chest", const = "EQUIP_SLOT_CHEST" },
	{ key = "hand", const = "EQUIP_SLOT_HAND" },
	{ key = "waist", const = "EQUIP_SLOT_WAIST" },
	{ key = "legs", const = "EQUIP_SLOT_LEGS" },
	{ key = "feet", const = "EQUIP_SLOT_FEET" },
	{ key = "neck", const = "EQUIP_SLOT_NECK" },
	{ key = "ring1", const = "EQUIP_SLOT_RING1" },
	{ key = "ring2", const = "EQUIP_SLOT_RING2" },
}

A.BARS = {
	{ key = "primary", const = "HOTBAR_CATEGORY_PRIMARY" },
	{ key = "backup", const = "HOTBAR_CATEGORY_BACKUP" },
}

-- The calls that change something, grouped by what one refusal takes down. Each group is asked about once
-- (see CheckGroup).
A.GROUPS = {
	equip = { "RequestEquipItem", "RequestUnequipItem" },
	skills = {
		"PrepareSkillPointAllocationRequest",
		"AddHotbarSlotChangeToAllocationRequest",
		"SendSkillPointAllocationRequest",
		"CancelSkillPointAllocationRequest",
	},
	champion = { "PrepareChampionPurchaseRequest", "AddHotbarSlotToChampionPurchaseRequest", "SendChampionPurchaseRequest" },
}

local DEFAULT_ICON = "EsoUI/Art/Icons/icon_missing.dds"

-- ---------------------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------------------

local function Plain(formatId, text)
	if type(text) ~= "string" then
		return ""
	end
	if zo_strformat and type(formatId) == "number" then
		local ok, formatted = pcall(zo_strformat, formatId, text)
		if ok and type(formatted) == "string" then
			return formatted
		end
	end
	return text
end
A.Plain = Plain

local function CountKeys(t)
	local n = 0
	if type(t) == "table" then
		for _ in pairs(t) do
			n = n + 1
		end
	end
	return n
end

-- ---------------------------------------------------------------------------------------
-- Text that the player typed
--
-- Lua's character classes (%s %c %a ...) and string.lower/upper ask the C library, which answers by the
-- process's locale. On a desk that is "C" and only ASCII counts. A game client need not run in "C": in a
-- Latin-1 locale 0x80-0x9F are control characters and 0xA0 and 0x85 are spaces -- and those are exactly the
-- bytes inside Japanese UTF-8 (こ is E3 81 93, だ is E3 81 A0). A name run through "%c" or "%s" can come out
-- cut in the middle of a character, and invalid UTF-8 handed to the client's text controls is the likely way
-- PB's Translate crashed a PS5 (0.4.16). The settings panel's name box goes straight to such a control.
--
-- So nothing below uses a class or lower/upper on the player's text: characters are read by byte value, a
-- name is made of whole, well-formed characters, and `/pbec status` reports what this console's locale does.
-- ---------------------------------------------------------------------------------------

A.MAX_NAME_CHARS = 24 -- what the panel's text box allows (ST_EDIT maxChars)

-- The length in bytes of the well-formed UTF-8 character that starts at index i, or nil when none does.
-- (Overlong forms, surrogates and anything above U+10FFFF are refused.)
local function CharSize(text, i)
	local b = text:byte(i)
	if not b then
		return nil
	end
	if b < 0x80 then
		return 1
	end
	local size, low, high
	if b >= 0xC2 and b <= 0xDF then
		size, low, high = 2, 0x80, 0xBF
	elseif b == 0xE0 then
		size, low, high = 3, 0xA0, 0xBF
	elseif b == 0xED then
		size, low, high = 3, 0x80, 0x9F
	elseif b >= 0xE1 and b <= 0xEF then
		size, low, high = 3, 0x80, 0xBF
	elseif b == 0xF0 then
		size, low, high = 4, 0x90, 0xBF
	elseif b >= 0xF1 and b <= 0xF3 then
		size, low, high = 4, 0x80, 0xBF
	elseif b == 0xF4 then
		size, low, high = 4, 0x80, 0x8F
	else
		return nil
	end
	local second = text:byte(i + 1)
	if not second or second < low or second > high then
		return nil
	end
	for k = i + 2, i + size - 1 do
		local c = text:byte(k)
		if not c or c < 0x80 or c > 0xBF then
			return nil
		end
	end
	return size
end

-- Is the whole string well-formed UTF-8?
function A.IsValidUTF8(text)
	if type(text) ~= "string" then
		return false
	end
	local i, length = 1, #text
	while i <= length do
		local size = CharSize(text, i)
		if not size then
			return false
		end
		i = i + size
	end
	return true
end

-- The well-formed characters of a string, in order; every byte that belongs to none is left out.
local function Characters(text)
	local list, i, length = {}, 1, #text
	while i <= length do
		local size = CharSize(text, i)
		if size then
			list[#list + 1] = text:sub(i, i + size - 1)
			i = i + size
		else
			i = i + 1
		end
	end
	return list
end

-- The string with its broken bytes dropped, and whether anything was dropped.
function A.SanitizeUTF8(text)
	text = tostring(text or "")
	if A.IsValidUTF8(text) then
		return text, false
	end
	return table.concat(Characters(text)), true
end

local IDEOGRAPHIC_SPACE, NO_BREAK_SPACE = "\227\128\128", "\194\160"
local LINE_SEPARATOR, PARAGRAPH_SEPARATOR = "\226\128\168", "\226\128\169"

local function IsBlank(ch)
	return ch == " " or ch == IDEOGRAPHIC_SPACE or ch == NO_BREAK_SPACE
end

-- Text for display and saving: whole characters only, control characters (C0, DEL, C1, line and paragraph
-- separators) become spaces, the ends are trimmed of spaces (ASCII, ideographic, no-break). `maxChars` cuts
-- on a character boundary.
function A.CleanText(text, maxChars)
	local chars = Characters(tostring(text or ""))
	for i, ch in ipairs(chars) do
		local b = ch:byte(1)
		if b < 32 or b == 127 or (b == 0xC2 and ch:byte(2) < 0xA0) or ch == LINE_SEPARATOR or ch == PARAGRAPH_SEPARATOR then
			chars[i] = " "
		end
	end
	local first, last = 1, #chars
	while first <= last and IsBlank(chars[first]) do
		first = first + 1
	end
	while last >= first and IsBlank(chars[last]) do
		last = last - 1
	end
	if maxChars and last - first + 1 > maxChars then
		last = first + maxChars - 1
		while last >= first and IsBlank(chars[last]) do
			last = last - 1
		end
	end
	return table.concat(chars, "", first, last)
end

-- A set's name as typed in the panel or after /pbec save.
function A.CleanName(text)
	return A.CleanText(text, A.MAX_NAME_CHARS)
end

-- ASCII-only lower case; every other byte is left exactly as it was.
function A.LowerAscii(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

local function IsAsciiBlank(b)
	return b == 32 or b == 9 or b == 10 or b == 13
end

function A.TrimAscii(text)
	text = tostring(text or "")
	local first, last = 1, #text
	while first <= last and IsAsciiBlank(text:byte(first)) do
		first = first + 1
	end
	while last >= first and IsAsciiBlank(text:byte(last)) do
		last = last - 1
	end
	return text:sub(first, last)
end

-- The words of a command line, split at ASCII blanks only.
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

-- What this Lua's locale does to UTF-8 bytes (one byte at a time, never on the player's text). The answers
-- are all `false` in the "C" locale; `true` anywhere means a class would have cut a Japanese character.
function A.ProbeLocale()
	local function matches(byte, class)
		return string.char(byte):find(class) ~= nil
	end
	local ok, result = pcall(function()
		return {
			control81 = matches(0x81, "%c"),
			space85 = matches(0x85, "%s"),
			spaceA0 = matches(0xA0, "%s"),
			letterE3 = matches(0xE3, "%a"),
			lowerChangesC3 = string.lower(string.char(0xC3)) ~= string.char(0xC3),
		}
	end)
	return ok and result or nil
end

-- Resolve the constants once: a missing one (an older or newer API) drops that slot instead of failing.
function A:ResolveConstants()
	for _, def in ipairs(self.GEAR) do
		def.slot = type(_G[def.const]) == "number" and _G[def.const] or nil
	end
	for _, bar in ipairs(self.BARS) do
		bar.cat = type(_G[bar.const]) == "number" and _G[bar.const] or nil
	end
	self.championCategory = type(HOTBAR_CATEGORY_CHAMPION) == "number" and HOTBAR_CATEGORY_CHAMPION or nil
end

-- ---------------------------------------------------------------------------------------
-- Saved variables
--
-- The file is account-wide; `chars` holds one table per character, keyed by the character id as a string.
--
-- `pending` is written before a guarded game call (and while the wheel page is up) and cleared when it
-- returns. If the game shows the UI error screen and the player reloads, the file still says "pending".
-- That is a hint, not proof: the file is also written on a normal logout, and a hard crash writes nothing at
-- all. So a leftover marker is only a *strike* against its group (`strikes`); the group is switched off
-- (`probe[group] = "bad"`) after STRIKES_TO_DISABLE strikes in a row, and any clean use clears the count.
-- Before 0.3.0 one leftover marker switched a group off for good, and a console has no easy way to type
-- /pbec retry: a page that vanished after one odd shutdown stayed gone. The first start of a newer schema
-- therefore forgets the old verdicts. /pbec retry (or the panel's button) forgets them on request.
-- ---------------------------------------------------------------------------------------

local SCHEMA = 3
local STRIKES_TO_DISABLE = 2
A.STRIKES_TO_DISABLE = STRIKES_TO_DISABLE

function A:Sanitize()
	local sv = self.sv
	for key, default in pairs(self.defaults) do
		if type(sv[key]) ~= type(default) then
			sv[key] = default
		end
	end
	sv.slot = math.max(1, math.min(self.NUM_SLOTS, math.floor(sv.slot)))
	if type(sv.chars) ~= "table" then
		sv.chars = {}
	end
	if type(sv.probe) ~= "table" then
		sv.probe = {}
	end
	if type(sv.strikes) ~= "table" then
		sv.strikes = {}
	end

	-- what this start-up found, for /pbec status
	local startup = { stale = nil, migrated = false, healed = 0 }
	self.startup = startup

	if sv.schema ~= SCHEMA then
		sv.probe, sv.strikes, sv.pending = {}, {}, nil
		sv.schema = SCHEMA
		startup.migrated = true
	end

	local pending = sv.pending
	sv.pending = nil
	if type(pending) == "string" then
		local group = pending == "wheelUse" and "wheel" or pending
		local count = (tonumber(sv.strikes[group]) or 0) + 1
		sv.strikes[group] = count
		startup.stale = pending
		if count >= STRIKES_TO_DISABLE then
			sv.probe[group] = "bad"
		end
	end

	-- Names saved by an older version may hold bytes that are not UTF-8 (see "Text that the player typed"); one
	-- of those shown in the panel or on the wheel is a crash waiting to happen. Make them whole characters again.
	for _, record in pairs(sv.chars) do
		if type(record) == "table" and type(record.slots) == "table" then
			for index, set in pairs(record.slots) do
				if type(set) == "table" then
					local name = A.CleanText(set.name)
					if name == "" then
						name = string.format(S.defaultName, tonumber(index) or 0)
					end
					if name ~= set.name then
						set.name = name
						startup.healed = startup.healed + 1
					end
				end
			end
		end
	end
end

function A:Reset()
	for key, default in pairs(self.defaults) do
		self.sv[key] = default
	end
end

function A:Set(key, value)
	if self.defaults[key] == nil then
		return
	end
	if type(value) ~= type(self.defaults[key]) then
		return
	end
	self.sv[key] = value
end

-- The record of the character that is playing now.
function A:Char()
	local id = "unknown"
	if GetCurrentCharacterId and Id64ToString then
		local ok, value = pcall(function()
			return Id64ToString(GetCurrentCharacterId())
		end)
		if ok and type(value) == "string" and value ~= "" then
			id = value
		end
	end
	local chars = self.sv.chars
	local record = chars[id]
	if type(record) ~= "table" then
		record = {}
		chars[id] = record
	end
	if type(record.slots) ~= "table" then
		record.slots = {}
	end
	if GetUnitName then
		local ok, name = pcall(GetUnitName, "player")
		if ok and type(name) == "string" and name ~= "" then
			record.name = Plain(SI_UNIT_NAME, name)
		end
	end
	return record
end

function A:GetSet(index)
	local set = self:Char().slots[index]
	if type(set) == "table" then
		return set
	end
	return nil
end

function A:DeleteSet(index)
	self:Char().slots[index] = nil
end

function A:RenameSet(index, name)
	local set = self:GetSet(index)
	if set then
		set.name = name
		return true
	end
	return false
end

-- The first slot without a set, or nil when all are taken.
function A:FirstFreeSlot()
	for i = 1, self.NUM_SLOTS do
		if not self:GetSet(i) then
			return i
		end
	end
	return nil
end

function A:SlotLabel(index)
	local set = self:GetSet(index)
	return string.format("%d: %s", index, set and set.name or S.emptySlot)
end

function A:Describe(set)
	if not set then
		return S.emptyDescription
	end
	local parts = {}
	if set.gear then
		parts[#parts + 1] = string.format(S.gearCount, set.gearCount or CountKeys(set.gear))
	end
	if set.bars then
		parts[#parts + 1] = string.format(S.skillCount, set.skillCount or 0)
	end
	if set.champion and (set.championCount or 0) > 0 then
		parts[#parts + 1] = string.format(S.championCount, set.championCount)
	end
	if #parts == 0 then
		return S.emptyDescription
	end
	return table.concat(parts, "  ")
end

-- ---------------------------------------------------------------------------------------
-- Reading what is worn and slotted now
-- ---------------------------------------------------------------------------------------

function A:WornUid(slot)
	if not GetWornItemInfo(BAG_WORN, slot) then
		return nil
	end
	return Id64ToString(GetItemUniqueId(BAG_WORN, slot))
end

-- Does the item at bag/index stand for the saved `want` in this slot definition?
function A:Matches(def, want, bag, index)
	if def.byLink then
		return GetItemLink(bag, index, LINK_STYLE_DEFAULT) == want.link
	end
	return Id64ToString(GetItemUniqueId(bag, index)) == want.uid
end

function A:CaptureGear()
	local gear, count = {}, 0
	for _, def in ipairs(self.GEAR) do
		if def.slot then
			local has, icon = GetWornItemInfo(BAG_WORN, def.slot)
			if has then
				gear[def.key] = {
					uid = Id64ToString(GetItemUniqueId(BAG_WORN, def.slot)),
					link = GetItemLink(BAG_WORN, def.slot, LINK_STYLE_DEFAULT),
					name = Plain(SI_TOOLTIP_ITEM_NAME, GetItemName(BAG_WORN, def.slot)),
					icon = icon,
				}
				count = count + 1
			end
		end
	end
	return gear, count
end

-- The progression's ability id of the morph that stands on the bar (what a skill request wants), or nil when
-- the client's skills data cannot say.
function A:ProgressionId(effectiveId)
	local manager = SKILLS_DATA_MANAGER
	if type(manager) ~= "table" or type(manager.GetProgressionDataByAbilityId) ~= "function" then
		return nil
	end
	local ok, id = pcall(function()
		local progression = manager:GetProgressionDataByAbilityId(effectiveId)
		return progression and progression:GetAbilityId() or nil
	end)
	if ok and type(id) == "number" then
		return id
	end
	return nil
end

-- The three script ids a crafted ability has now, as { primary, secondary, tertiary }; nil when unknown.
function A:ActiveScripts(craftedAbilityId)
	if type(GetCraftedAbilityActiveScriptIds) ~= "function" then
		return nil
	end
	local ok, primary, secondary, tertiary = pcall(GetCraftedAbilityActiveScriptIds, craftedAbilityId)
	if ok and type(primary) == "number" then
		return { primary, secondary or 0, tertiary or 0 }
	end
	return nil
end

function A:CaptureSkills()
	local bars, count = {}, 0
	local first, last = 3, 8
	if GetAssignableAbilityBarStartAndEndSlots then
		local a, b = GetAssignableAbilityBarStartAndEndSlots()
		if type(a) == "number" and type(b) == "number" then
			first, last = a, b
		end
	end
	for _, bar in ipairs(self.BARS) do
		if bar.cat then
			local slots = {}
			for slot = first, last do
				local actionType = GetSlotType(slot, bar.cat)
				if actionType == ACTION_TYPE_ABILITY or actionType == ACTION_TYPE_CRAFTED_ABILITY then
					local id = GetSlotBoundId(slot, bar.cat)
					local name
					if actionType == ACTION_TYPE_CRAFTED_ABILITY then
						name = GetCraftedAbilityDisplayName(id)
					else
						name = GetAbilityName(id)
					end
					local entry = {
						t = actionType,
						id = id,
						name = Plain(SI_ABILITY_NAME, name),
						icon = GetSlotTexture(slot, bar.cat),
					}
					if actionType == ACTION_TYPE_ABILITY then
						entry.pid = self:ProgressionId(id)
					else
						entry.scripts = self:ActiveScripts(id)
					end
					slots[slot] = entry
					count = count + 1
				end
			end
			bars[bar.key] = slots
		end
	end
	return bars, count
end

-- The champion star in a bar slot, 0 when the slot is empty.
function A:ChampionAt(slot)
	local cat = self.championCategory
	if not cat then
		return 0
	end
	if ACTION_TYPE_CHAMPION_SKILL and GetSlotType(slot, cat) ~= ACTION_TYPE_CHAMPION_SKILL then
		return 0
	end
	local id = GetSlotBoundId(slot, cat)
	return type(id) == "number" and id or 0
end

function A:ChampionSlotRange()
	local first, last = 1, 12
	if GetAssignableChampionBarStartAndEndSlots then
		local a, b = GetAssignableChampionBarStartAndEndSlots()
		if type(a) == "number" and type(b) == "number" then
			first, last = a, b
		end
	end
	return first, last
end

-- nil when there is no champion bar to read (the system is not unlocked yet).
function A:CaptureChampion()
	if not self.championCategory then
		return nil
	end
	if IsChampionSystemUnlocked and not IsChampionSystemUnlocked() then
		return nil
	end
	local slots, count = {}, 0
	local first, last = self:ChampionSlotRange()
	for slot = first, last do
		local id = self:ChampionAt(slot)
		if id ~= 0 then
			local name = GetChampionSkillName and GetChampionSkillName(id) or tostring(id)
			slots[slot] = { id = id, name = Plain(nil, name) }
			count = count + 1
		end
	end
	return slots, count
end

-- A new set from what the character wears and has slotted at this moment; nil and a reason when the settings
-- leave nothing to record.
function A:Capture(name)
	local sv = self.sv
	local set = { name = name }
	if sv.saveGear then
		local gear, count = self:CaptureGear()
		if count > 0 then
			set.gear, set.gearCount = gear, count
		end
	end
	if sv.saveSkills then
		local bars, count = self:CaptureSkills()
		set.bars, set.skillCount = bars, count
	end
	if sv.saveChampion then
		local champion, count = self:CaptureChampion()
		if champion then
			set.champion, set.championCount = champion, count
		end
	end
	if not set.gear and not set.bars and (set.championCount or 0) == 0 then
		return nil, S.nothingToSave
	end
	-- the icon on the wheel: the main hand, else the first thing worn, else the first skill
	local icon
	if set.gear then
		if set.gear.mainHand then
			icon = set.gear.mainHand.icon
		else
			for _, def in ipairs(self.GEAR) do
				if set.gear[def.key] and set.gear[def.key].icon then
					icon = set.gear[def.key].icon
					break
				end
			end
		end
	end
	if not icon and set.bars and set.bars.primary then
		for slot = 1, 20 do
			local entry = set.bars.primary[slot]
			if entry and entry.icon then
				icon = entry.icon
				break
			end
		end
	end
	set.icon = icon or DEFAULT_ICON
	return set
end

function A:SaveSet(index, name)
	name = A.CleanName(name)
	if name == "" then
		name = string.format(S.defaultName, index)
	end
	local set, why = self:Capture(name)
	if not set then
		return false, why
	end
	self:Char().slots[index] = set
	return true, set
end

-- ---------------------------------------------------------------------------------------
-- Asking the game whether a call may be made
--
-- The calls that change gear and skills are documented without a private marker, and that marker has been
-- wrong before; a private call raises the client's UI error, which pcall does not catch. So the API is
-- asked first (IsPrivateFunction / IsProtectedFunction) and, either way, `pending` is written to the saved
-- variables before a call and cleared when it returns (Sanitize).
-- ---------------------------------------------------------------------------------------

A.api = {}

function A:CheckGroup(group)
	local state = self.api[group]
	if state then
		return state.usable, state.why
	end
	state = { usable = false, kinds = {}, asked = "" }
	self.api[group] = state
	local probe = self.sv.probe

	for _, name in ipairs(self.GROUPS[group]) do
		if type(_G[name]) ~= "function" then
			state.why = string.format(S.whyMissing, name)
			return false, state.why
		end
	end
	if probe[group] == "bad" then
		state.why = S.whyEarlier
		return false, state.why
	end

	if probe.ask == "bad" then
		state.asked = "skipped: the question failed on an earlier login"
	elseif type(IsPrivateFunction) == "function" and type(IsProtectedFunction) == "function" then
		local before = self.sv.pending
		self.sv.pending = "ask"
		local refused
		for _, name in ipairs(self.GROUPS[group]) do
			local okPrivate, isPrivate = pcall(IsPrivateFunction, name)
			local okProtected, isProtected = pcall(IsProtectedFunction, name)
			if okPrivate and okProtected then
				state.kinds[name] = isPrivate and "private" or (isProtected and "protected" or "allowed")
				if isPrivate or isProtected then
					refused = refused or name
				end
			else
				state.kinds[name] = "question failed"
			end
		end
		self.sv.pending = before
		state.asked = refused and "refused" or "answered"
		if refused then
			state.why = string.format(S.whyPrivate, refused)
			return false, state.why
		end
	else
		state.asked = "cannot ask"
	end
	state.usable = true
	return true
end

-- May a single function be called? Asked once; true when the game cannot be asked.
function A:Allowed(name)
	self.allowed = self.allowed or {}
	local known = self.allowed[name]
	if known ~= nil then
		return known
	end
	local answer = type(_G[name]) == "function"
	if answer and self.sv.probe.ask ~= "bad" and type(IsPrivateFunction) == "function" and type(IsProtectedFunction) == "function" then
		local before = self.sv.pending
		self.sv.pending = "ask"
		local okPrivate, isPrivate = pcall(IsPrivateFunction, name)
		local okProtected, isProtected = pcall(IsProtectedFunction, name)
		self.sv.pending = before
		if okPrivate and okProtected and (isPrivate or isProtected) then
			answer = false
		end
	end
	self.allowed[name] = answer
	return answer
end

-- Call a guarded function. Returns false and the reason when the group is refused or the call raised.
function A:Call(group, name, ...)
	local usable, why = self:CheckGroup(group)
	if not usable then
		return false, why
	end
	local sv = self.sv
	-- put back whatever was marked before (the wheel page's "in use" mark is still up while a load that the wheel
	-- started makes its first call)
	local before = sv.pending
	sv.pending = group
	local ok, a, b = pcall(_G[name], ...)
	sv.pending = before
	if ok then
		sv.probe[group] = "ok"
		sv.strikes[group] = nil
	end
	return ok, a, b
end

-- Forget what was learned about the calls (and the strikes against them); they are asked about again.
function A:Retry()
	self.sv.probe = {}
	self.sv.strikes = {}
	self.sv.pending = nil
	self.api = {}
	self.allowed = {}
end
