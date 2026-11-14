-- KelaPadUI trait research matrix
--
-- Left pane: every character on the current server, logged-in character first,
-- each with a two-line research summary.  Right pane: one scrollable page showing
-- every crafting research line against its traits and active research below it.
--
-- Research knowledge of the current character comes from the base-game API.
-- Every other character is read from LibCharacterKnowledge when that library is
-- installed; without it only the logged-in character is listed.
--
-- Item availability ("an unlocked item for this trait exists") is derived from
-- the item links the client can see:
--   * current character -> backpack and bank
--   * other character   -> bank only (the bank is shared per server)
--
-- The game keeps three separate trait sets (weapon, armor and jewelry), so the
-- page is split into one section per set; a single set of trait rows cannot
-- label every research line.  The weapon and jewelry sections share the first
-- row because together they only need 14 columns, which keeps everything on one
-- page and leaves the rows tall enough for legible text and icons.  Every
-- section uses the same column width, so the weapon and armor columns line up
-- vertically, and the jewelry section is right-aligned to keep it out of the way.
--
-- No XML template is used: the panes and the page are built in Lua from
-- base-game virtual templates.  Refresh requests from smithing events, inventory
-- events and LibCharacterKnowledge are coalesced into a single deferred rebuild,
-- so overlapping triggers can never rebuild twice.

local ADDON_EVENTS = "KelaPadUI_TraitResearch"
local ADDON_TIMER = "KelaPadUI_TraitResearchTimer"
local SCENE_NAME = "kelaTraitResearch"

local STYLES = kpuiConst.TextStyles

-- Colours come from the shared style set, so the page cannot drift from the rest
-- of the add-on.
local WHITE = STYLES.Body.color
local GOLD = STYLES.ValueTimer.color
local LIGHT_GREEN = STYLES.ValuePositive.color
local LIGHT_ORANGE = STYLES.ValueWarning.color
local LIGHT_RED = STYLES.ValueNegative.color

-- Cell states.
local CELL_KNOWN = 1
local CELL_RESEARCHING = 2
local CELL_AVAILABLE = 3
local CELL_NONE = 4

-- The researching glyph is the base-game research timer icon: a circle with a
-- clock face, tinted yellow.  Swap the entry for a plain dot texture if a
-- filled circle without the clock face is preferred.
local CELL_TEXTURE =
{
	[CELL_KNOWN] = ZO_CHECK_ICON,
	[CELL_RESEARCHING] = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_timer32.dds",
	[CELL_AVAILABLE] = "EsoUI/Art/Buttons/Gamepad/gp_plus_large.dds",
	[CELL_NONE] = "EsoUI/Art/Buttons/closeButton_up.dds",
}

local CELL_COLOR =
{
	[CELL_KNOWN] = LIGHT_GREEN,
	[CELL_RESEARCHING] = GOLD,
	[CELL_AVAILABLE] = LIGHT_ORANGE,
	[CELL_NONE] = LIGHT_RED,
}

-- closeButton_up.dds is a 32x32 texture whose X is drawn in the top-left 20x20
-- (the game's own close button crops it with 0.625); drawn whole, the X sits
-- up-left and small.  Crop it, and reset every other state to the full texture
-- so a stale crop cannot leak when a cell changes state.
--
-- Careful: SetTextureCoords takes (left, right, top, bottom) -- not the
-- (left, top, right, bottom) order the XML <TextureCoords> attributes use.
local CELL_TEXTURE_COORDS =
{
	[CELL_NONE] = { 0, 0.625, 0, 0.625 },
}
local FULL_TEXTURE_COORDS = { 0, 1, 0, 1 }

local TIMER_INTERVAL_MS = 15 * 1000
local COMPLETION_RETENTION_SECONDS = 7 * 24 * 60 * 60
local AVAILABILITY_REFRESH_DELAY_MS = 200

-- Research lines per group, with the heading each group carries.  The line
-- indices mirror the game's own research line order and
-- LibCharacterKnowledge's item lookups.  Groups that do not fit the installed
-- game data are dropped during setup.
local PANEL_GROUPS =
{
	{ craft = CRAFTING_TYPE_BLACKSMITHING, firstLine = 1, lastLine = 7, title = KELA_TRAIT_RESEARCH_TITLE_BLACKSMITHING },
	{ craft = CRAFTING_TYPE_BLACKSMITHING, firstLine = 8, lastLine = 14, title = KELA_TRAIT_RESEARCH_TITLE_HEAVY_ARMOR },
	{ craft = CRAFTING_TYPE_CLOTHIER, firstLine = 1, lastLine = 7, title = KELA_TRAIT_RESEARCH_TITLE_LIGHT_ARMOR },
	{ craft = CRAFTING_TYPE_CLOTHIER, firstLine = 8, lastLine = 14, title = KELA_TRAIT_RESEARCH_TITLE_MEDIUM_ARMOR },
	{ craft = CRAFTING_TYPE_WOODWORKING, firstLine = 1, lastLine = 5, title = KELA_TRAIT_RESEARCH_TITLE_WOODWORKING },
	{ craft = CRAFTING_TYPE_WOODWORKING, firstLine = 6, lastLine = 6, title = KELA_TRAIT_RESEARCH_TITLE_SHIELD },
	-- The jewelry section already carries the Jewelry name, so its group shows
	-- only its count.
	{ craft = CRAFTING_TYPE_JEWELRYCRAFTING, firstLine = 1, lastLine = 2 },
}

-- Which trait-category sections share a page row, and the name each section
-- carries.  A category with no research lines is skipped.  Sections are placed
-- left to right unless they opt into right alignment.
local SECTION_LAYOUT =
{
	{
		{ category = ITEM_TRAIT_TYPE_CATEGORY_WEAPON, name = KELA_TRAIT_RESEARCH_SECTION_WEAPONS },
		{ category = ITEM_TRAIT_TYPE_CATEGORY_JEWELRY, name = KELA_TRAIT_RESEARCH_SECTION_JEWELRY, alignRight = true },
	},
	{
		{ category = ITEM_TRAIT_TYPE_CATEGORY_ARMOR, name = KELA_TRAIT_RESEARCH_SECTION_ARMOR },
	},
}

-- Item link to research indices, matching the game's own layout.  Equip types
-- that resolve to -1 are weapons and are looked up by weapon type instead.
local EQUIP_LINE_LOOKUP =
{
	[EQUIP_TYPE_CHEST] = 1,
	[EQUIP_TYPE_FEET] = 2,
	[EQUIP_TYPE_HAND] = 3,
	[EQUIP_TYPE_HEAD] = 4,
	[EQUIP_TYPE_LEGS] = 5,
	[EQUIP_TYPE_SHOULDERS] = 6,
	[EQUIP_TYPE_WAIST] = 7,
	[EQUIP_TYPE_RING] = 1,
	[EQUIP_TYPE_NECK] = 2,
	[EQUIP_TYPE_MAIN_HAND] = -1,
	[EQUIP_TYPE_OFF_HAND] = -1,
	[EQUIP_TYPE_ONE_HAND] = -1,
	[EQUIP_TYPE_TWO_HAND] = -1,
}

local WEAPON_LINE_LOOKUP =
{
	[WEAPONTYPE_AXE] = 1,
	[WEAPONTYPE_HAMMER] = 2,
	[WEAPONTYPE_SWORD] = 3,
	[WEAPONTYPE_TWO_HANDED_AXE] = 4,
	[WEAPONTYPE_TWO_HANDED_HAMMER] = 5,
	[WEAPONTYPE_TWO_HANDED_SWORD] = 6,
	[WEAPONTYPE_DAGGER] = 7,
	[WEAPONTYPE_BOW] = 1,
	[WEAPONTYPE_FIRE_STAFF] = 2,
	[WEAPONTYPE_FROST_STAFF] = 3,
	[WEAPONTYPE_LIGHTNING_STAFF] = 4,
	[WEAPONTYPE_HEALING_STAFF] = 5,
	[WEAPONTYPE_SHIELD] = 6,
}

local TRAIT_INDEX_LOOKUP =
{
	[ITEM_TRAIT_TYPE_ARMOR_STURDY] = 1,
	[ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE] = 2,
	[ITEM_TRAIT_TYPE_ARMOR_REINFORCED] = 3,
	[ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED] = 4,
	[ITEM_TRAIT_TYPE_ARMOR_TRAINING] = 5,
	[ITEM_TRAIT_TYPE_ARMOR_INFUSED] = 6,
	[ITEM_TRAIT_TYPE_ARMOR_PROSPEROUS] = 7,
	[ITEM_TRAIT_TYPE_ARMOR_DIVINES] = 8,
	[ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = 9,
	[ITEM_TRAIT_TYPE_WEAPON_POWERED] = 1,
	[ITEM_TRAIT_TYPE_WEAPON_CHARGED] = 2,
	[ITEM_TRAIT_TYPE_WEAPON_PRECISE] = 3,
	[ITEM_TRAIT_TYPE_WEAPON_INFUSED] = 4,
	[ITEM_TRAIT_TYPE_WEAPON_DEFENDING] = 5,
	[ITEM_TRAIT_TYPE_WEAPON_TRAINING] = 6,
	[ITEM_TRAIT_TYPE_WEAPON_SHARPENED] = 7,
	[ITEM_TRAIT_TYPE_WEAPON_DECISIVE] = 8,
	[ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = 9,
	[ITEM_TRAIT_TYPE_JEWELRY_ARCANE] = 1,
	[ITEM_TRAIT_TYPE_JEWELRY_HEALTHY] = 2,
	[ITEM_TRAIT_TYPE_JEWELRY_ROBUST] = 3,
	[ITEM_TRAIT_TYPE_JEWELRY_TRIUNE] = 4,
	[ITEM_TRAIT_TYPE_JEWELRY_INFUSED] = 5,
	[ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE] = 6,
	[ITEM_TRAIT_TYPE_JEWELRY_SWIFT] = 7,
	[ITEM_TRAIT_TYPE_JEWELRY_HARMONY] = 8,
	[ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY] = 9,
}

local ARMOR_LINE_OFFSET =
{
	[ARMORTYPE_MEDIUM] = 7,
	[ARMORTYPE_HEAVY] = 7,
}

-- Page geometry, in gamepad reference units.  The right pane spans quadrants 2
-- to 4, so its size is derived from the gamepad layout constants rather than
-- measured, which is only valid once the pane has been laid out.
local UI_REFERENCE_HEIGHT = 1080
local TRAIT_COLUMN_WIDTH = 170
local BAND_GAP = 20
-- Separation between the page rows, so the weapon row and the armor row read as
-- two distinct blocks.
local BAND_ROW_GAP = 20
-- Separation between neighbouring groups inside a section.
local GROUP_GAP = 16
-- The header block above the tables: the character name line, the detail line
-- sitting under it, and the clear space before the first table.  The name line
-- is sized for the CharacterName font, so the bigger name is not squeezed.
local NAME_LINE_HEIGHT = 46
local NAME_DETAIL_GAP = 2
local DETAIL_LINE_HEIGHT = 22
local TOP_STRIP_HEIGHT = NAME_LINE_HEIGHT + NAME_DETAIL_GAP + DETAIL_LINE_HEIGHT
-- Clear space between the header block and the first research table.
local TOP_STRIP_GAP = 20
local GROUP_LINE_HEIGHT = 22
-- One line of text, plus enough padding for the taller section name.
local GROUP_HEADER_HEIGHT = GROUP_LINE_HEIGHT + 4
local ITEM_ICON_ROW_HEIGHT = 32
local LAYOUT_SAFETY_MARGIN = 0
-- A group made of one research line would otherwise be too narrow to hold its
-- heading and count on one line, so headings have a minimum width.
local MIN_HEADING_WIDTH = 130
local ROW_HEIGHT_DEFAULT = 30
local ROW_HEIGHT_MIN = 20
local ROW_HEIGHT_MAX = 40
-- Vertical breathing room kept inside each trait row, so the cells never touch
-- the row above or below.
local ROW_CELL_PADDING = 4

-- Active research is grouped by crafting station below the matrix.  Each entry
-- has its trait, research line and countdown on one line, with no fixed limit.
local ACTIVE_RESEARCH_GAP = 20
local ACTIVE_RESEARCH_HEADING_HEIGHT = 26
local ACTIVE_RESEARCH_HEADING_GAP = 8
local ACTIVE_RESEARCH_COLUMN_HEADER_HEIGHT = 24
local ACTIVE_RESEARCH_ENTRY_HEIGHT = 22
local ACTIVE_RESEARCH_COLUMN_GAP = 12
local ACTIVE_RESEARCH_CRAFTS =
{
	{ craft = CRAFTING_TYPE_BLACKSMITHING, title = KELA_TRAIT_RESEARCH_TITLE_BLACKSMITHING },
	{ craft = CRAFTING_TYPE_CLOTHIER, title = KELA_TRAIT_RESEARCH_TITLE_CLOTHIER },
	{ craft = CRAFTING_TYPE_WOODWORKING, title = KELA_TRAIT_RESEARCH_TITLE_WOODWORKING },
	{ craft = CRAFTING_TYPE_JEWELRYCRAFTING, title = KELA_TRAIT_RESEARCH_TITLE_JEWELRY },
}

local BANK_BAGS = { BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Mirrors LibCharacterKnowledge's server naming so the saved completion records
-- use the same keys whether or not the library is installed.
local SERVER_NAMES =
{
	["NA Megaserver"] = "NA",
	["EU Megaserver"] = "EU",
	["XB1live"] = "NA",
	["XB1live-eu"] = "EU",
	["PS4live"] = "NA",
	["PS4live-eu"] = "EU",
}

local research =
{
	selectedServer = nil,
	selectedCharId = nil,
}

-- ---------------------------------------------------------------------------
-- General helpers
-- ---------------------------------------------------------------------------

local function GetCurrentServer()
	if LibCharacterKnowledge then
		local servers = LibCharacterKnowledge.GetServerList()
		if servers and servers[1] then
			return servers[1]
		end
	end

	local worldName = GetWorldName()
	return SERVER_NAMES[worldName] or worldName
end

-- ---------------------------------------------------------------------------
-- Item scan
-- ---------------------------------------------------------------------------

local function GetResearchIndicesFromItemLink(itemLink)
	local craftingSkillType = GetItemLinkCraftingSkillType(itemLink)
	if not craftingSkillType or GetNumSmithingResearchLines(craftingSkillType) == 0 then
		return nil
	end

	local researchLineIndex = EQUIP_LINE_LOOKUP[select(4, GetItemLinkInfo(itemLink))]
	if researchLineIndex == -1 then
		researchLineIndex = WEAPON_LINE_LOOKUP[GetItemLinkWeaponType(itemLink)]
	elseif researchLineIndex then
		researchLineIndex = researchLineIndex + (ARMOR_LINE_OFFSET[GetItemLinkArmorType(itemLink)] or 0)
	end

	local traitIndex = TRAIT_INDEX_LOOKUP[GetItemLinkTraitType(itemLink)]
	if researchLineIndex and traitIndex then
		return craftingSkillType, researchLineIndex, traitIndex
	end
	return nil
end

local function MarkAvailable(available, craftingSkillType, researchLineIndex, traitIndex)
	local byCraft = available[craftingSkillType]
	if not byCraft then
		byCraft = {}
		available[craftingSkillType] = byCraft
	end

	local byLine = byCraft[researchLineIndex]
	if not byLine then
		byLine = {}
		byCraft[researchLineIndex] = byLine
	end

	byLine[traitIndex] = true
end

-- Returns two lookup tables keyed craft -> line -> trait:
--   currentAvailable: traits the current character can research from backpack
--                     or bank items
--   bankAvailable:    traits present on any unlocked bank item, regardless of
--                     what the current character already knows
local function ScanAvailability()
	local currentAvailable = {}
	local bankAvailable = {}

	local function ScanBag(bagId, isBank)
		local bagSize = GetBagSize(bagId)
		for slotIndex = 1, bagSize do
			local itemLink = GetItemLink(bagId, slotIndex)
			if itemLink and itemLink ~= "" then
				local traitInformation = GetItemTraitInformation(bagId, slotIndex)
				local hasResearchableTrait = traitInformation == ITEM_TRAIT_INFORMATION_NONE
					or traitInformation == ITEM_TRAIT_INFORMATION_CAN_BE_RESEARCHED
				local isBlocked = traitInformation == ITEM_TRAIT_INFORMATION_RETRAITED
					or traitInformation == ITEM_TRAIT_INFORMATION_RECONSTRUCTED

				if hasResearchableTrait and not isBlocked and not IsItemPlayerLocked(bagId, slotIndex) then
					local craftingSkillType, researchLineIndex, traitIndex = GetResearchIndicesFromItemLink(itemLink)
					if craftingSkillType then
						if isBank then
							MarkAvailable(bankAvailable, craftingSkillType, researchLineIndex, traitIndex)
						end
						if ZO_SharedSmithingResearch.IsResearchableItem(bagId, slotIndex, craftingSkillType, researchLineIndex, traitIndex) then
							MarkAvailable(currentAvailable, craftingSkillType, researchLineIndex, traitIndex)
						end
					end
				end
			end
		end
	end

	ScanBag(BAG_BACKPACK, false)
	for _, bagId in ipairs(BANK_BAGS) do
		if GetBagSize(bagId) > 0 then
			ScanBag(bagId, true)
		end
	end

	return currentAvailable, bankAvailable
end

-- ---------------------------------------------------------------------------
-- Completion timestamps
-- ---------------------------------------------------------------------------

local function GetCompletionStorage()
	if type(kpuiSavedVariables) ~= "table" then
		return nil
	end
	if type(kpuiSavedVariables.traitResearchCompletions) ~= "table" then
		kpuiSavedVariables.traitResearchCompletions = {}
	end
	return kpuiSavedVariables.traitResearchCompletions
end

local function GetCompletionKey(craftingSkillType, researchLineIndex, traitIndex)
	return craftingSkillType .. ":" .. researchLineIndex .. ":" .. traitIndex
end

local function RecordCompletion(server, charId, craftingSkillType, researchLineIndex, traitIndex, timestamp)
	local storage = GetCompletionStorage()
	if not storage or not server or not charId then
		return
	end

	local byServer = storage[server]
	if not byServer then
		byServer = {}
		storage[server] = byServer
	end
	local byCharacter = byServer[charId]
	if not byCharacter then
		byCharacter = {}
		byServer[charId] = byCharacter
	end

	byCharacter[GetCompletionKey(craftingSkillType, researchLineIndex, traitIndex)] = timestamp
end

-- Prunes entries older than the retention window and returns the most recent
-- completion timestamp still inside it.
local function GetRecentCompletion(server, charId, now)
	local storage = GetCompletionStorage()
	if not storage or not server or not charId then
		return nil
	end

	local byServer = storage[server]
	local byCharacter = byServer and byServer[charId]
	if not byCharacter then
		return nil
	end

	local newest
	for key, timestamp in pairs(byCharacter) do
		if type(timestamp) ~= "number" or now - timestamp > COMPLETION_RETENTION_SECONDS then
			byCharacter[key] = nil
		elseif not newest or timestamp > newest then
			newest = timestamp
		end
	end

	return newest
end

-- ---------------------------------------------------------------------------
-- Per character data
-- ---------------------------------------------------------------------------

local function BuildCharacterData(server, charId, name, isCurrent, now, availability)
	local data =
	{
		server = server,
		charId = charId,
		name = name,
		isCurrent = isCurrent,
		hasData = true,
		researched = 0,
		total = 0,
		inProgress = 0,
		activeResearch = {},
		cells = {},
	}

	local library = LibCharacterKnowledge

	if not isCurrent and library then
		-- One probe tells us whether the library holds any research data for
		-- this character at all.
		local knowledge = library.GetSmithingResearchStatusForCharacter(CRAFTING_TYPE_BLACKSMITHING, 1, 1, server, charId)
		if knowledge == nil or knowledge == library.KNOWLEDGE_NODATA then
			data.hasData = false
		end
	end

	local earlierCompletion

	for _, band in ipairs(research.bands) do
		for _, group in ipairs(band.groups) do
			local byCraft = data.cells[group.craft]
			if not byCraft then
				byCraft = {}
				data.cells[group.craft] = byCraft
			end

			for researchLineIndex = group.firstLine, group.lastLine do
				local lineCells = {}
				byCraft[researchLineIndex] = lineCells

				local numTraits = select(3, GetSmithingResearchLineInfo(group.craft, researchLineIndex))
				for traitIndex = 1, numTraits do
					data.total = data.total + 1

					local isKnown = false
					local remaining
					if isCurrent then
						isKnown = select(3, GetSmithingResearchLineTraitInfo(group.craft, researchLineIndex, traitIndex)) and true or false
						remaining = select(2, GetSmithingResearchLineTraitTimes(group.craft, researchLineIndex, traitIndex))
					elseif library and data.hasData then
						local knowledge, timeRemaining = library.GetSmithingResearchStatusForCharacter(group.craft, researchLineIndex, traitIndex, server, charId)
						remaining = timeRemaining
						if knowledge == library.KNOWLEDGE_KNOWN then
							isKnown = true
						elseif knowledge == library.KNOWLEDGE_UNKNOWN and remaining and remaining <= 0 then
							-- Mirrors the library's own trait wrapper: an
							-- unlearned trait whose stored timer has expired is
							-- complete.
							isKnown = true
						end
					end

					local cell
					if isKnown then
						cell = CELL_KNOWN
						data.researched = data.researched + 1
					elseif remaining and remaining > 0 then
						cell = CELL_RESEARCHING
						data.inProgress = data.inProgress + 1
						local completionAt = now + remaining
						local active = data.activeResearch[group.craft]
						if not active then
							active = {}
							data.activeResearch[group.craft] = active
						end
						local line = group.lines[researchLineIndex - group.firstLine + 1]
						active[#active + 1] =
						{
							name = line.name,
							groupTitle = group.craft == CRAFTING_TYPE_CLOTHIER and group.title or nil,
							traitType = group.traits[traitIndex].type,
							completionAt = completionAt,
						}
						if not earlierCompletion or completionAt < earlierCompletion then
							earlierCompletion = completionAt
						end
					elseif availability
						and availability[group.craft]
						and availability[group.craft][researchLineIndex]
						and availability[group.craft][researchLineIndex][traitIndex] then
						cell = CELL_AVAILABLE
					else
						cell = CELL_NONE
					end

					lineCells[traitIndex] = cell
				end
			end
		end
	end

	for _, active in pairs(data.activeResearch) do
		table.sort(active, function(a, b)
			if a.completionAt == b.completionAt then
				return a.name < b.name
			end
			return a.completionAt < b.completionAt
		end)
	end

	data.nextCompletionAt = earlierCompletion
	data.recentCompletionAt = GetRecentCompletion(server, charId, now)
	return data
end

local function FormatTimeLeft(seconds)
	if not seconds or seconds < 0 then
		seconds = 0
	end
	return ZO_FormatTime(seconds, TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
end

local function GetResearchedText(data)
	local text = string.format("%d/%d", data.researched, data.total)
	if data.total > 0 and data.researched >= data.total then
		text = LIGHT_GREEN:Colorize(text)
	end
	return zo_strformat(GetString(KELA_TRAIT_RESEARCH_RESEARCHED), text)
end

local function GetInProgressText(data, now)
	if data.inProgress > 0 then
		local text = zo_strformat(GetString(KELA_TRAIT_RESEARCH_IN_PROGRESS), data.inProgress)
		if data.nextCompletionAt then
			text = text .. " - " .. GOLD:Colorize(FormatTimeLeft(data.nextCompletionAt - now))
		end
		return text
	end

	if data.recentCompletionAt then
		return LIGHT_GREEN:Colorize(GetString(KELA_TRAIT_RESEARCH_COMPLETED))
	end

	return ""
end

-- ---------------------------------------------------------------------------
-- Page structure
-- ---------------------------------------------------------------------------

local function GetTraitIcon(traitType)
	local icons = research.traitIconByType
	if not icons then
		icons = {}
		for traitItemIndex = 1, GetNumSmithingTraitItems() do
			local traitType, _, icon = GetSmithingTraitItemInfo(traitItemIndex)
			if traitType then
				icons[traitType] = icon
			end
		end
		research.traitIconByType = icons
	end
	return icons[traitType]
end

-- Builds the validated group list, each carrying the trait category its lines
-- belong to and the trait list its rows must show.
local function BuildGroups()
	local groups = {}

	for _, definition in ipairs(PANEL_GROUPS) do
		local craft = definition.craft
		if GetNumSmithingResearchLines(craft) >= definition.lastLine then
			local firstTraitType = GetSmithingResearchLineTraitInfo(craft, definition.firstLine, 1)
			local numTraits = select(3, GetSmithingResearchLineInfo(craft, definition.firstLine))

			local lines = {}
			for researchLineIndex = definition.firstLine, definition.lastLine do
				local name, icon = GetSmithingResearchLineInfo(craft, researchLineIndex)
				lines[#lines + 1] = { craft = craft, index = researchLineIndex, name = name, icon = icon }
			end

			local traits = {}
			for traitIndex = 1, numTraits do
				local traitType = GetSmithingResearchLineTraitInfo(craft, definition.firstLine, traitIndex)
				traits[traitIndex] = { type = traitType, icon = GetTraitIcon(traitType) }
			end

			groups[#groups + 1] =
			{
				craft = craft,
				-- A group without a title is labelled by its count alone.
				title = definition.title and GetString(definition.title) or nil,
				category = GetItemTraitTypeCategory(firstTraitType),
				firstLine = definition.firstLine,
				lastLine = definition.lastLine,
				numTraits = numTraits,
				lines = lines,
				traits = traits,
			}
		end
	end

	return groups
end

-- Groups the groups by trait category, then arranges the categories into the
-- page rows declared by SECTION_LAYOUT.
local function BuildPageStructure()
	local byCategory = {}
	for _, category in ipairs({
		ITEM_TRAIT_TYPE_CATEGORY_WEAPON,
		ITEM_TRAIT_TYPE_CATEGORY_ARMOR,
		ITEM_TRAIT_TYPE_CATEGORY_JEWELRY })
	do
		byCategory[category] = {}
	end

	local groups = BuildGroups()
	for _, group in ipairs(groups) do
		local band = byCategory[group.category]
		if band then
			band[#band + 1] = group
		end
	end

	-- Bands stay a flat list: BuildCharacterData walks every research line once.
	local bands = {}
	local bandRows = {}

	for _, rowDefinition in ipairs(SECTION_LAYOUT) do
		local bandRow = { bands = {} }

		for _, section in ipairs(rowDefinition) do
			local band = byCategory[section.category]
			if band and #band > 0 then
				local columns = 0
				local numTraits = 0
				for _, group in ipairs(band) do
					group.firstColumn = columns + 1
					columns = columns + #group.lines
					group.lastColumn = columns
					if group.numTraits > numTraits then
						numTraits = group.numTraits
					end
				end

				local columnList = {}
				for _, group in ipairs(band) do
					for _, line in ipairs(group.lines) do
						columnList[#columnList + 1] = line
					end
				end

				local bandInfo =
				{
					category = section.category,
					title = section.name,
					alignRight = section.alignRight,
					groups = band,
					columnList = columnList,
					columns = columns,
					numTraits = numTraits,
					x = 0,
				}

				research.bands[#research.bands + 1] = bandInfo
				bandRow.bands[#bandRow.bands + 1] = bandInfo
			end
		end

		if #bandRow.bands > 0 then
			bandRows[#bandRows + 1] = bandRow
		end
	end

	research.bandRows = bandRows
end

-- Splits the right pane between the page rows, then sizes every section.  One
-- column width is used across the whole page so the weapon and armor columns
-- line up vertically.  Every field a later pass reads is assigned here.
local function InitializeLayout()
	local paneWidth = ZO_GAMEPAD_UI_REFERENCE_WIDTH - ZO_GAMEPAD_SAFE_ZONE_INSET_X
		- (ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X)
	local paneHeight = UI_REFERENCE_HEIGHT - ZO_GAMEPAD_QUADRANT_TOP_OFFSET - 62
		+ ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET
	research.paneWidth = paneWidth

	local rowCount = #research.bandRows
	local perRowHeight = ROW_HEIGHT_DEFAULT
	if rowCount > 0 then
		local available = paneHeight - TOP_STRIP_HEIGHT - TOP_STRIP_GAP - LAYOUT_SAFETY_MARGIN
			- ((rowCount - 1) * BAND_ROW_GAP)
		perRowHeight = math.floor(available / rowCount)
	end

	-- The narrowest row wins, so no section can overflow the pane.
	local columnWidth
	for _, bandRow in ipairs(research.bandRows) do
		local totalColumns = 0
		local totalGroupGaps = 0
		for _, band in ipairs(bandRow.bands) do
			totalColumns = totalColumns + band.columns
			totalGroupGaps = totalGroupGaps + math.max(#band.groups - 1, 0) * GROUP_GAP
		end

		local usableWidth = paneWidth - (#bandRow.bands * TRAIT_COLUMN_WIDTH)
			- ((#bandRow.bands - 1) * BAND_GAP) - totalGroupGaps
		local width = math.floor(usableWidth / math.max(totalColumns, 1))
		if not columnWidth or width < columnWidth then
			columnWidth = width
		end
	end
	research.columnWidth = math.max(columnWidth or 24, 24)

	for _, bandRow in ipairs(research.bandRows) do
		local traitRows = 0
		for _, band in ipairs(bandRow.bands) do
			if band.numTraits > traitRows then
				traitRows = band.numTraits
			end
		end

		bandRow.columnWidth = research.columnWidth
		bandRow.traitRows = math.max(traitRows, 1)

		local fixedHeight = GROUP_HEADER_HEIGHT + ITEM_ICON_ROW_HEIGHT
		bandRow.rowHeight = zo_clamp(
			math.floor((perRowHeight - fixedHeight) / bandRow.traitRows),
			ROW_HEIGHT_MIN,
			ROW_HEIGHT_MAX)
		local padding = math.min(ROW_CELL_PADDING, math.max(bandRow.rowHeight - 14, 0))
		bandRow.cellSize = math.max(14, bandRow.rowHeight - padding)
		bandRow.itemIconSize = math.max(16, math.min(ITEM_ICON_ROW_HEIGHT - 4, bandRow.columnWidth - 12))
		bandRow.height = fixedHeight + bandRow.traitRows * bandRow.rowHeight

		-- Horizontal placement.  Headings are centred on their group's columns,
		-- but are widened to a minimum so a single-column group still fits its
		-- heading and count, then kept inside the pane.
		local bandX = 0
		for _, band in ipairs(bandRow.bands) do
			local bandWidth = TRAIT_COLUMN_WIDTH + band.columns * bandRow.columnWidth
				+ math.max(#band.groups - 1, 0) * GROUP_GAP
			if band.alignRight then
				band.x = paneWidth - bandWidth
			else
				band.x = bandX
				bandX = bandX + bandWidth + BAND_GAP
			end

			local x = band.x + TRAIT_COLUMN_WIDTH
			local columnX = {}
			for _, group in ipairs(band.groups) do
				local spanX = x
				for columnIndex = group.firstColumn, group.lastColumn do
					columnX[columnIndex] = x
					x = x + bandRow.columnWidth
				end

				local spanWidth = x - spanX
				local headingWidth = math.max(spanWidth, MIN_HEADING_WIDTH)
				local headingX = spanX + ((spanWidth - headingWidth) / 2)
				if headingX + headingWidth > paneWidth then
					headingX = paneWidth - headingWidth
				end
				if headingX < 0 then
					headingX = 0
					headingWidth = math.min(headingWidth, paneWidth)
				end
				group.headingX = headingX
				group.headingWidth = headingWidth

				x = x + GROUP_GAP
			end
			band.columnX = columnX
		end
	end
end

-- ---------------------------------------------------------------------------
-- Page controls
-- ---------------------------------------------------------------------------

-- Labels are created from a shared style, so every piece of text on the page
-- takes its font and colour from kpuiConst.TextStyles.
local function CreateLabel(parent, name, style)
	local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	KelaApplyTextStyle(label, style)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	return label
end

local function CreateTexture(parent, name, size)
	local texture = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	texture:SetDimensions(size, size)
	return texture
end

local function BuildPage(parent)
	local page = { name = nil, detail = nil, bandRows = {} }

	page.name = CreateLabel(parent, "KelaTraitResearchCharacter", STYLES.CharacterName)
	page.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	page.name:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
	page.name:SetHeight(NAME_LINE_HEIGHT)

	-- The detail line sits under the name.
	page.detail = CreateLabel(parent, "KelaTraitResearchDetail", STYLES.Body)
	page.detail:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	page.detail:SetAnchor(TOPLEFT, page.name, BOTTOMLEFT, 0, NAME_DETAIL_GAP)
	page.detail:SetHeight(DETAIL_LINE_HEIGHT)

	local rowY = TOP_STRIP_HEIGHT + TOP_STRIP_GAP

	for rowIndex, bandRow in ipairs(research.bandRows) do
		local bandRowControls = { bands = {} }
		local headerTextY = rowY + math.floor((GROUP_HEADER_HEIGHT - GROUP_LINE_HEIGHT) / 2)

		for bandIndex, band in ipairs(bandRow.bands) do
			local bandControls = { sectionNames = {}, groupTitles = {}, itemIcons = {}, traitIcons = {}, traitNames = {}, cells = {} }
			local prefix = "KelaTraitResearchR" .. rowIndex .. "B" .. bandIndex

			-- Section name, sitting in the trait label column of the header row.
			-- Built exactly like the group headings below it, and its text is
			-- re-asserted on every render like theirs.
			local sectionName = CreateLabel(parent, prefix .. "Section", STYLES.SectionTitle)
			sectionName:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
			sectionName:SetAnchor(TOPLEFT, parent, TOPLEFT, band.x, rowY)
			sectionName:SetWidth(TRAIT_COLUMN_WIDTH)
			sectionName:SetHeight(GROUP_HEADER_HEIGHT)
			sectionName:SetText(GetString(band.title))
			bandControls.sectionNames[1] = sectionName

			-- One heading line per group, carrying its name and count.
			for groupIndex, group in ipairs(band.groups) do
				local groupTitle = CreateLabel(parent, prefix .. "G" .. groupIndex, STYLES.Body)
				groupTitle:SetAnchor(TOPLEFT, parent, TOPLEFT, group.headingX, headerTextY)
				groupTitle:SetWidth(group.headingWidth)
				groupTitle:SetHeight(GROUP_LINE_HEIGHT)
				bandControls.groupTitles[groupIndex] = groupTitle
			end

			-- Research-line icons, one per column.
			local iconY = rowY + GROUP_HEADER_HEIGHT + math.floor((ITEM_ICON_ROW_HEIGHT - bandRow.itemIconSize) / 2)
			for columnIndex = 1, band.columns do
				local icon = CreateTexture(parent, prefix .. "I" .. columnIndex, bandRow.itemIconSize)
				icon:SetAnchor(TOPLEFT, parent, TOPLEFT,
					band.columnX[columnIndex] + math.floor((bandRow.columnWidth - bandRow.itemIconSize) / 2),
					iconY)
				bandControls.itemIcons[columnIndex] = icon
			end

			-- Trait rows: icon and name in the label column, then the cells.
			local rowsY = rowY + GROUP_HEADER_HEIGHT + ITEM_ICON_ROW_HEIGHT
			for traitRowIndex = 1, band.numTraits do
				local traitRowY = rowsY + (traitRowIndex - 1) * bandRow.rowHeight

				local traitIcon = CreateTexture(parent, prefix .. "T" .. traitRowIndex, bandRow.cellSize)
				traitIcon:SetAnchor(TOPLEFT, parent, TOPLEFT, band.x, traitRowY + math.floor((bandRow.rowHeight - bandRow.cellSize) / 2))
				bandControls.traitIcons[traitRowIndex] = traitIcon

				local traitName = CreateLabel(parent, prefix .. "N" .. traitRowIndex, STYLES.BodyLarge)
				traitName:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
				traitName:SetAnchor(TOPLEFT, parent, TOPLEFT, band.x + bandRow.cellSize + 8, traitRowY)
				traitName:SetWidth(TRAIT_COLUMN_WIDTH - bandRow.cellSize - 12)
				traitName:SetHeight(bandRow.rowHeight)
				bandControls.traitNames[traitRowIndex] = traitName

				local rowCells = {}
				for columnIndex = 1, band.columns do
					local cell = CreateTexture(parent, prefix .. "C" .. traitRowIndex .. "_" .. columnIndex, bandRow.cellSize)
					cell:SetAnchor(TOPLEFT, parent, TOPLEFT,
						band.columnX[columnIndex] + math.floor((bandRow.columnWidth - bandRow.cellSize) / 2),
						traitRowY + math.floor((bandRow.rowHeight - bandRow.cellSize) / 2))
					rowCells[columnIndex] = cell
				end
				bandControls.cells[traitRowIndex] = rowCells
			end

			bandRowControls.bands[bandIndex] = bandControls
		end

		page.bandRows[rowIndex] = bandRowControls
		rowY = rowY + bandRow.height + BAND_ROW_GAP
	end

	page.matrixHeight = rowY - (#research.bandRows > 0 and BAND_ROW_GAP or 0)
	page.activeY = page.matrixHeight + ACTIVE_RESEARCH_GAP
	page.activeTitle = CreateLabel(parent, "KelaTraitResearchActiveTitle", STYLES.SectionTitle)
	page.activeTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	page.activeTitle:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, page.activeY)
	page.activeTitle:SetWidth(research.paneWidth)
	page.activeTitle:SetHeight(ACTIVE_RESEARCH_HEADING_HEIGHT)
	page.activeTitle:SetText(GetString(KELA_TRAIT_RESEARCH_ACTIVE_HEADER))

	page.activeColumns = {}
	local columnWidth = (research.paneWidth - (#ACTIVE_RESEARCH_CRAFTS - 1) * ACTIVE_RESEARCH_COLUMN_GAP) / #ACTIVE_RESEARCH_CRAFTS
	for index, definition in ipairs(ACTIVE_RESEARCH_CRAFTS) do
		local x = (index - 1) * (columnWidth + ACTIVE_RESEARCH_COLUMN_GAP)
		local header = CreateLabel(parent, "KelaTraitResearchActiveHeader" .. index, STYLES.Body)
		header:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		header:SetAnchor(TOPLEFT, parent, TOPLEFT, x, page.activeY + ACTIVE_RESEARCH_HEADING_HEIGHT + ACTIVE_RESEARCH_HEADING_GAP)
		header:SetDimensions(columnWidth, ACTIVE_RESEARCH_COLUMN_HEADER_HEIGHT)
		header:SetText(GetString(definition.title))
		page.activeColumns[index] = { header = header, entries = {}, x = x, width = columnWidth }
	end

	return page
end

local function RenderActiveResearch(page, data, now)
	local hasActive = data.inProgress > 0
	page.activeTitle:SetHidden(not hasActive)
	local maxEntries = 0
	for index, definition in ipairs(ACTIVE_RESEARCH_CRAFTS) do
		local column = page.activeColumns[index]
		local active = data.activeResearch[definition.craft] or {}
		column.header:SetHidden(not hasActive)
		local count = hasActive and math.max(#active, 1) or 0
		maxEntries = math.max(maxEntries, count)
		for entryIndex = 1, count do
			local entry = column.entries[entryIndex]
			if not entry then
				local prefix = "KelaTraitResearchActive" .. index .. "Entry" .. entryIndex
				local y = page.activeY + ACTIVE_RESEARCH_HEADING_HEIGHT + ACTIVE_RESEARCH_HEADING_GAP + ACTIVE_RESEARCH_COLUMN_HEADER_HEIGHT
					+ (entryIndex - 1) * ACTIVE_RESEARCH_ENTRY_HEIGHT
				local name = CreateLabel(page.parent, prefix .. "Name", STYLES.Body)
				name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
				name:SetAnchor(TOPLEFT, page.parent, TOPLEFT, column.x, y)
				name:SetDimensions(column.width, ACTIVE_RESEARCH_ENTRY_HEIGHT)
				local timer = CreateLabel(page.parent, prefix .. "Timer", STYLES.Body)
				timer:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
				timer:SetAnchor(TOPLEFT, name, TOPRIGHT, 0, 0)
				timer:SetDimensions(column.width, ACTIVE_RESEARCH_ENTRY_HEIGHT)
				entry = { name = name, timer = timer }
				column.entries[entryIndex] = entry
			end
			local item = active[entryIndex]
			local name = item and item.name or "-"
			if item then
				if item.groupTitle then
					name = item.groupTitle .. ": " .. name
				end
				name = GetString("SI_ITEMTRAITTYPE", item.traitType) .. " " .. name
			end
			-- Reserve room for the countdown before truncating a long item name.
			entry.timer:SetWidth(column.width)
			entry.timer:SetText(item and (" - " .. GOLD:Colorize(FormatTimeLeft(item.completionAt - now))) or "")
			local timerWidth = item and math.min(column.width, entry.timer:GetTextWidth() + 2) or 0
			entry.timer:SetWidth(timerWidth)
			entry.timer:SetHidden(not item)
			entry.name:SetWidth(column.width)
			entry.name:SetText(name)
			entry.name:SetWidth(math.max(0, math.min(entry.name:GetTextWidth() + 2, column.width - timerWidth)))
			entry.name:SetHidden(false)
		end
		for entryIndex = count + 1, #column.entries do
			column.entries[entryIndex].name:SetHidden(true)
			column.entries[entryIndex].timer:SetHidden(true)
		end
	end
	local height = page.matrixHeight
	if hasActive then
		height = page.activeY + ACTIVE_RESEARCH_HEADING_HEIGHT + ACTIVE_RESEARCH_HEADING_GAP + ACTIVE_RESEARCH_COLUMN_HEADER_HEIGHT
			+ maxEntries * ACTIVE_RESEARCH_ENTRY_HEIGHT
	end
	if page.contentHeight ~= height then
		page.contentHeight = height
		page.parent:SetHeight(height)
	end
end

local function GetSelectedCharacter()
	return research.characters and research.characters[research.selectedCharacterIndex]
end

local function GetLineCells(data, line)
	local byCraft = data.cells[line.craft]
	return byCraft and byCraft[line.index]
end

local function RenderPage(now)
	local page = research.page
	local data = GetSelectedCharacter()
	if not page or not data then
		return
	end

	local nameText = data.name
	if data.total > 0 and data.researched >= data.total then
		nameText = LIGHT_GREEN:Colorize(nameText)
	end
	page.name:SetText(nameText)

	if not LibCharacterKnowledge then
		page.detail:SetColor(GOLD:UnpackRGBA())
		page.detail:SetText(GetString(KELA_TRAIT_RESEARCH_NO_LCK))
	elseif not data.isCurrent and not data.hasData then
		page.detail:SetColor(LIGHT_RED:UnpackRGBA())
		page.detail:SetText(GetString(KELA_TRAIT_RESEARCH_NO_DATA))
	else
		page.detail:SetColor(STYLES.Body.color:UnpackRGBA())
		local text = GetResearchedText(data)
		local progressText = GetInProgressText(data, now)
		if progressText ~= "" then
			text = text .. "   " .. progressText
		end
		page.detail:SetText(text)
	end
	RenderActiveResearch(page, data, now)

	for rowIndex, bandRow in ipairs(research.bandRows) do
		local bandRowControls = page.bandRows[rowIndex]
		if bandRowControls then
			for bandIndex, band in ipairs(bandRow.bands) do
				local bandControls = bandRowControls.bands[bandIndex]
				if bandControls then
					for traitRowIndex = 1, band.numTraits do
						local trait = band.groups[1].traits[traitRowIndex]
						if trait then
							bandControls.traitNames[traitRowIndex]:SetText(GetString("SI_ITEMTRAITTYPE", trait.type))
							if trait.icon then
								bandControls.traitIcons[traitRowIndex]:SetTexture(trait.icon)
							end
						end
					end

					for columnIndex, line in ipairs(band.columnList) do
						local itemIcon = bandControls.itemIcons[columnIndex]
						if itemIcon and line.icon then
							itemIcon:SetTexture(line.icon)
						end

						local lineCells = GetLineCells(data, line)
						for traitRowIndex = 1, band.numTraits do
							local cell = lineCells and lineCells[traitRowIndex] or CELL_NONE
							local texture = bandControls.cells[traitRowIndex] and bandControls.cells[traitRowIndex][columnIndex]
							if texture then
								local coords = CELL_TEXTURE_COORDS[cell] or FULL_TEXTURE_COORDS
								texture:SetTextureCoords(coords[1], coords[2], coords[3], coords[4])
								texture:SetTexture(CELL_TEXTURE[cell])
								texture:SetColor(CELL_COLOR[cell]:UnpackRGBA())
							end
						end
					end

					for groupIndex, group in ipairs(band.groups) do
						local researched, total = 0, 0
						for columnIndex = group.firstColumn, group.lastColumn do
							local lineCells = GetLineCells(data, band.columnList[columnIndex])
							if lineCells then
								for traitRowIndex = 1, group.numTraits do
									total = total + 1
									if lineCells[traitRowIndex] == CELL_KNOWN then
										researched = researched + 1
									end
								end
							end
						end

						local countText = string.format("%d/%d", researched, total)
						if total > 0 and researched >= total then
							countText = LIGHT_GREEN:Colorize(countText)
						end

						local titleControl = bandControls.groupTitles[groupIndex]
						titleControl:SetColor(STYLES.Body.color:UnpackRGBA())
						if group.title then
							titleControl:SetText(group.title .. "  " .. countText)
						else
							titleControl:SetText(countText)
						end
					end

					local sectionControl = bandControls.sectionNames[1]
					if sectionControl then
						sectionControl:SetColor(STYLES.SectionTitle.color:UnpackRGBA())
						sectionControl:SetText(GetString(band.title))
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Left pane rows
-- ---------------------------------------------------------------------------

-- Headers in this list look like the game's own list headers: bold, uppercase,
-- the interface normal text colour, and left-aligned to the same indent as the
-- character names below them.  The colour comes from the entry data (applied by
-- ZO_SharedGamepadEntry_OnSetup and re-applied on every refresh); the alignment
-- and indent are set here.
local function HeaderRowSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
	data.fontScaleOnSelection = false
	ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
	control.label:SetFont(STYLES.ListHeader.font)
	control.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	control.label:ClearAnchors()
	control.label:SetAnchor(TOPLEFT, control, TOPLEFT, ZO_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT, 0)
	control.label:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
end

local function AddHeaderRow(list, text)
	local entry = ZO_GamepadEntryData:New(text, nil)
	entry.canSelect = false
	KelaApplyEntryTextStyle(entry, STYLES.ListHeader)
	list:AddEntry("ZO_GamepadFullWidthLabelEntryTemplate", entry)
end

local function AddCharacterRow(list, character)
	local entry = ZO_GamepadEntryData:New(character.name, nil)
	entry.characterData = character

	-- Core-managed sub-labels: the list creates and stacks them, feeds them into
	-- the row height, and re-evaluates these providers on every refresh.
	entry:AddSubLabel(function()
		return GetResearchedText(character)
	end)
	entry:AddSubLabel(function()
		return GetInProgressText(character, GetTimeStamp())
	end)

	list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
end

local function BuildList()
	local list = research.list
	if not list or not research.characters then
		return
	end

	list:Clear()

	AddHeaderRow(list, GetString(KELA_TRAIT_RESEARCH_HEADER_CHARACTERS))

	research.rowIndexByCharacter = {}
	for index, character in ipairs(research.characters) do
		AddCharacterRow(list, character)
		research.rowIndexByCharacter[index] = list:GetNumEntries()
	end

	list:Commit()

	local rowIndex = research.rowIndexByCharacter[research.selectedCharacterIndex] or 1
	list:SetSelectedIndexWithoutAnimation(rowIndex, true)
end

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------

local function OnListSelectionChanged()
	local list = research.list
	if not list then
		return
	end

	local data = list:GetTargetData() or list:GetSelectedData()
	local character = data and data.characterData

	if not character then
		-- Fallback: map the selected row index back to a character, so the page
		-- still follows the list even if the row's own reference is unavailable.
		local rowIndex = list.GetSelectedIndex and list:GetSelectedIndex()
		for index, characterRow in pairs(research.rowIndexByCharacter or {}) do
			if characterRow == rowIndex then
				character = research.characters and research.characters[index]
				break
			end
		end
	end

	if not character then
		return
	end

	local changedCharacter = research.selectedServer ~= character.server or research.selectedCharId ~= character.charId
	research.selectedServer = character.server
	research.selectedCharId = character.charId
	if changedCharacter and research.scroll then
		research.scroll:ResetToTop()
	end

	for index, candidate in ipairs(research.characters or {}) do
		if candidate == character then
			research.selectedCharacterIndex = index
			break
		end
	end

	RenderPage(GetTimeStamp())
end

-- ---------------------------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------------------------

local function RebuildCharacters()
	local now = GetTimeStamp()
	local currentServer = GetCurrentServer()
	local currentCharacterId = GetCurrentCharacterId()
	local library = LibCharacterKnowledge

	local currentAvailable, bankAvailable = ScanAvailability()

	local characters = {}

	-- Only the characters on the server being played: the bank is per server, so
	-- a character elsewhere cannot be given item availability at all.
	if library then
		for _, character in ipairs(library.GetCharacterList(currentServer)) do
			if character.id == currentCharacterId then
				characters[#characters + 1] = BuildCharacterData(currentServer, character.id, character.name, true, now, currentAvailable)
			else
				characters[#characters + 1] = BuildCharacterData(currentServer, character.id, character.name, false, now, bankAvailable)
			end
		end
	end

	local hasCurrentCharacter = false
	for _, character in ipairs(characters) do
		if character.isCurrent then
			hasCurrentCharacter = true
			break
		end
	end

	-- Without the library only the logged-in character is known.
	if not hasCurrentCharacter then
		local playerName = zo_strformat("<<1>>", GetUnitName("player"))
		table.insert(characters, 1, BuildCharacterData(currentServer, currentCharacterId, playerName, true, now, currentAvailable))
	end

	-- Current character first, then the library order.
	local ordered = {}
	for _, character in ipairs(characters) do
		if character.isCurrent then
			ordered[#ordered + 1] = character
		end
	end
	for _, character in ipairs(characters) do
		if not character.isCurrent then
			ordered[#ordered + 1] = character
		end
	end

	research.characters = ordered
end

local function ResolveSelectedCharacterIndex()
	local server = research.selectedServer
	local charId = research.selectedCharId
	if server and charId then
		for index, character in ipairs(research.characters or {}) do
			if character.server == server and character.charId == charId then
				return index
			end
		end
	end
	return 1
end

local function Rebuild()
	research.refreshScheduled = false

	local now = GetTimeStamp()

	RebuildCharacters()
	research.selectedCharacterIndex = ResolveSelectedCharacterIndex()

	-- Completions observed as in-progress on an earlier pass are recorded once
	-- their predicted time has passed.
	if research.pendingCompletions then
		for _, pending in ipairs(research.pendingCompletions) do
			if pending.completionAt <= now then
				RecordCompletion(pending.server, pending.charId, pending.craftingSkillType, pending.researchLineIndex, pending.traitIndex, pending.completionAt)
			end
		end
	end

	research.pendingCompletions = {}
	for _, character in ipairs(research.characters) do
		if character.nextCompletionAt then
			research.pendingCompletions[#research.pendingCompletions + 1] =
			{
				server = character.server,
				charId = character.charId,
				completionAt = character.nextCompletionAt,
			}
		end
	end

	for _, character in ipairs(research.characters) do
		character.recentCompletionAt = GetRecentCompletion(character.server, character.charId, now)
	end

	local selected = research.characters[research.selectedCharacterIndex]
	if selected then
		research.selectedServer = selected.server
		research.selectedCharId = selected.charId
	end

	BuildList()
	RenderPage(now)
end

local function RequestRefresh(delay)
	if research.refreshScheduled then
		return
	end
	research.refreshScheduled = true
	zo_callLater(function()
		if research.isShowing then
			Rebuild()
		else
			research.refreshScheduled = false
			research.dirty = true
		end
	end, delay or 0)
end

local function OnTimer()
	local now = GetTimeStamp()

	-- A cached completion has passed, so the cell states changed.
	for _, character in ipairs(research.characters or {}) do
		if character.nextCompletionAt and character.nextCompletionAt <= now then
			Rebuild()
			return
		end
	end

	if research.list and research.list:HasEntries() then
		research.list:RefreshVisible()
	end
	RenderPage(now)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

local function OnSmithingResearchChanged()
	RequestRefresh(AVAILABILITY_REFRESH_DELAY_MS)
end

local function OnSmithingResearchCompleted(_, craftingSkillType, researchLineIndex, traitIndex)
	local server = GetCurrentServer()
	local charId = GetCurrentCharacterId()
	if server and charId then
		RecordCompletion(server, charId, craftingSkillType, researchLineIndex, traitIndex, GetTimeStamp())
	end
	OnSmithingResearchChanged()
end

local function OnInventorySlotChanged(_, bagId)
	if bagId == BAG_BACKPACK or bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
		RequestRefresh(AVAILABILITY_REFRESH_DELAY_MS)
	end
end

local function OnInventoryFullUpdate()
	RequestRefresh(AVAILABILITY_REFRESH_DELAY_MS)
end

local function OnLibraryRefresh()
	-- Coalesced with the smithing and inventory events, so a library refresh and
	-- a smithing event arriving together still produce a single rebuild.
	RequestRefresh(AVAILABILITY_REFRESH_DELAY_MS)
end

local function OnLibraryInitialized()
	RequestRefresh(0)
end

local function RegisterEvents()
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, OnSmithingResearchChanged)
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, OnSmithingResearchChanged)
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, OnSmithingResearchCompleted)
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED, OnSmithingResearchChanged)

	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotChanged)
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_INVENTORY_FULL_UPDATE, OnInventoryFullUpdate)
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_INVENTORY_SLOT_LOCKED, OnInventorySlotChanged)
	EVENT_MANAGER:RegisterForEvent(ADDON_EVENTS, EVENT_INVENTORY_SLOT_UNLOCKED, OnInventorySlotChanged)

	if LibCharacterKnowledge then
		LibCharacterKnowledge.RegisterForCallback(ADDON_EVENTS, LibCharacterKnowledge.EVENT_INITIALIZED, OnLibraryInitialized)
		LibCharacterKnowledge.RegisterForCallback(ADDON_EVENTS, LibCharacterKnowledge.EVENT_UPDATE_REFRESH, OnLibraryRefresh)
	end
end

-- ---------------------------------------------------------------------------
-- Scene
-- ---------------------------------------------------------------------------

local function InitializeKeybindStripDescriptors()
	research.keybindStripDescriptor =
	{
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
	}
	ZO_Gamepad_AddBackNavigationKeybindDescriptors(research.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
	ZO_Gamepad_AddListTriggerKeybindDescriptors(research.keybindStripDescriptor, research.list)
end

local function OnSceneStateChanged(_, newState)
	if newState == SCENE_SHOWING then
		research.isShowing = true
		if research.dirty or not research.characters then
			Rebuild()
			research.dirty = false
		end
		KEYBIND_STRIP:AddKeybindButtonGroup(research.keybindStripDescriptor)
		EVENT_MANAGER:RegisterForUpdate(ADDON_TIMER, TIMER_INTERVAL_MS, OnTimer)
		research.list:Activate()
	elseif newState == SCENE_HIDING then
		research.isShowing = false
		EVENT_MANAGER:UnregisterForUpdate(ADDON_TIMER)
		research.list:Deactivate()
		KEYBIND_STRIP:RemoveKeybindButtonGroup(research.keybindStripDescriptor)
	end
end

local function CreateScene()
	local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)

	local root = CreateTopLevelWindow("KelaTraitResearchRoot")
	root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
	root:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
	research.root = root

	local title = CreateLabel(root, "KelaTraitResearchTitle", STYLES.Title)
	title:SetAnchor(TOPLEFT, root, TOPLEFT, ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X, ZO_GAMEPAD_QUADRANT_TOP_OFFSET)
	title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -ZO_GAMEPAD_SAFE_ZONE_INSET_X, ZO_GAMEPAD_QUADRANT_TOP_OFFSET)
	title:SetHeight(48)
	title:SetText(GetString(KELA_TRAIT_RESEARCH_TITLE))

	local leftPane = CreateControl("KelaTraitResearchLeftPane", root, CT_CONTROL)
	leftPane:SetAnchor(TOPLEFT, root, TOPLEFT, ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X, ZO_GAMEPAD_QUADRANT_TOP_OFFSET + 62)
	leftPane:SetAnchor(BOTTOMLEFT, root, BOTTOMLEFT, ZO_GAMEPAD_QUADRANT_1_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X, ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET)
	leftPane:SetWidth(ZO_GAMEPAD_CONTENT_WIDTH)

	local rightPane = CreateControl("KelaTraitResearchRightPane", root, CT_CONTROL)
	rightPane:SetAnchor(TOPLEFT, root, TOPLEFT, ZO_GAMEPAD_QUADRANT_2_LEFT_OFFSET + ZO_GAMEPAD_CONTENT_INSET_X, ZO_GAMEPAD_QUADRANT_TOP_OFFSET + 62)
	rightPane:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, -ZO_GAMEPAD_SAFE_ZONE_INSET_X, ZO_GAMEPAD_QUADRANT_BOTTOM_OFFSET)

	local listControl = CreateControlFromVirtual("KelaTraitResearchList", leftPane, "ZO_VerticalParametricScrollListTemplate")
	listControl:SetAnchor(TOPLEFT, leftPane, TOPLEFT, 0, 0)
	listControl:SetAnchor(BOTTOMRIGHT, leftPane, BOTTOMRIGHT, 0, 0)

	local list = ZO_GamepadVerticalItemParametricScrollList:New(listControl)
	list:SetAlignToScreenCenter(false)
	list:AddDataTemplate("ZO_GamepadFullWidthLabelEntryTemplate", HeaderRowSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
	list:AddDataTemplate("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
	list:SetOnTargetDataChangedCallback(OnListSelectionChanged)
	list:SetOnSelectedDataChangedCallback(OnListSelectionChanged)
	research.list = list

	local scroll = CreateControlFromVirtual("KelaTraitResearchScroll", rightPane, "ZO_ScrollContainer_Gamepad")
	scroll:SetAnchorFill(rightPane)
	local scrollChild = scroll:GetNamedChild("ScrollChild")
	scrollChild:SetResizeToFitDescendents(false)
	scrollChild:SetWidth(research.paneWidth)
	research.scroll = scroll
	research.page = BuildPage(scrollChild)
	research.page.parent = scrollChild

	scene:RegisterCallback("StateChange", OnSceneStateChanged)
	scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
	scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_RIGHT)
	scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
	scene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT)
	scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
	scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
	scene:AddFragment(ZO_FadeSceneFragment:New(root))

	research.scene = scene
	root:SetHidden(true)
end

local initialized = false

function KelaSetupTraitResearch()
	if initialized then
		return
	end
	initialized = true

	research.bands = {}
	BuildPageStructure()
	InitializeLayout()
	CreateScene()
	InitializeKeybindStripDescriptors()
	RegisterEvents()

	research.dirty = true
end
