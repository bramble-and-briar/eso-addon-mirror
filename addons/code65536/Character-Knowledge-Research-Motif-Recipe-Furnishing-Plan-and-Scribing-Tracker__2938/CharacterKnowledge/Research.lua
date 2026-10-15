local LCCC = LibCodesCommonCode
local LCK = LibCharacterKnowledge
local LEJ = LibExtendedJournal
local CharacterKnowledge = CharacterKnowledge
local CharacterKnowledgeList = CharacterKnowledgeList


--------------------------------------------------------------------------------
-- Improved FormatTimeSeconds
--------------------------------------------------------------------------------

local TIME_FORMAT_STYLE_DAY_AND_COLONS = 0x100

local function FormatTimeSecondsEx( time, formatType, ... )
	time = zo_max(time, 0)
	local result
	if (formatType == TIME_FORMAT_STYLE_DAY_AND_COLONS) then
		local s = time % 60; time = zo_floor(time / 60)
		local m = time % 60; time = zo_floor(time / 60)
		local h = time % 24; time = zo_floor(time / 24)
		local d = time
		if (d > 0) then
			result = string.format("%s  %02d:%02d:%02d", FormatTimeSeconds(d * 86400, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT), h, m, s)
		elseif (h > 0) then
			result = string.format("%d:%02d:%02d", h, m, s)
		else
			result = string.format("%d:%02d", m, s)
		end
	else
		result = FormatTimeSeconds(time, formatType, ...)
		result = result:gsub(" ", " ")
		result = result:gsub(" +", " ")
		result = result:gsub("(%d) ", "%1")
		result = result:gsub(" $", "")
	end
	return result
end


--------------------------------------------------------------------------------
-- CharacterKnowledge.GetTradeEligibility
-- Simplified adaptation from LibMultiAccountSets
--------------------------------------------------------------------------------

function CharacterKnowledge.GetTradeEligibility( itemLink, itemSource, account )
	if (IsItemLinkBound(itemLink)) then
		return account == CharacterKnowledge.userId
	elseif (GetItemLinkBindType(itemLink) == BIND_TYPE_ON_PICKUP) then
		if (itemSource and itemSource.bagId and itemSource.slotIndex) then
			-- Inventory and banks
			return IsDisplayNameInItemBoPAccountTable(itemSource.bagId, itemSource.slotIndex, UndecorateDisplayName(account))
		elseif (itemSource and itemSource.who and itemSource.tradeIndex) then
			-- Trade slots
			return string.find(GetTradeItemBoPTradeableDisplayNamesString(itemSource.who, itemSource.tradeIndex) .. " ", account .. "[%s,]") ~= nil
		else
			return account == CharacterKnowledge.userId
		end
	else
		return true
	end
end


--------------------------------------------------------------------------------
-- CharacterKnowledge.ResearchGetColoredNameList
-- Mode 1: verbose format, for grid tooltips
-- Mode 2: compact format, for item tooltips
--------------------------------------------------------------------------------

function CharacterKnowledge.ResearchGetColoredNameList( craftingSkillType, researchLineIndex, traitIndex, mode, param1, param2 )
	local server, account, itemLink, itemSource
	if (mode == 1) then
		server, account = param1, param2
	elseif (mode == 2) then
		itemLink, itemSource = param1, param2
	end

	local results = { }
	local found = 0
	local total = 0

	for _, character in ipairs(LCK.GetSmithingResearchStatusForCharacters(craftingSkillType, researchLineIndex, traitIndex, server, nil, account)) do
		if (mode == 1) then
			-- Handle in-progress research
			local activeColorOverride = nil
			local activeTimeLeft = ""
			if (character.knowledge == LCK.KNOWLEDGE_UNKNOWN and character.remaining) then
				if (character.remaining <= 0) then
					character.knowledge = LCK.KNOWLEDGE_KNOWN
				else
					activeColorOverride = 3
					activeTimeLeft = string.format(" (%s)", FormatTimeSecondsEx(character.remaining, TIME_FORMAT_STYLE_SHOW_LARGEST_TWO_UNITS))
				end
			end

			local color = LCK.IsKnowledgeUsable(character.knowledge) and LEJ.GetTooltipColor(1, activeColorOverride or character.knowledge) or LEJ.GetTooltipColor(2, 0)

			if (character.id == CharacterKnowledge.charId) then
				table.insert(results, string.format("|c%06X|l0:1:1:1:1:%06X|l%s|l|r%s", color, color, character.name, activeTimeLeft))
			else
				table.insert(results, string.format("|c%06X%s|r%s", color, character.name, activeTimeLeft))
			end

			-- Ensure wrapping happens at the boundaries of each entry
			results[#results] = string.gsub(results[#results], " ", " ")

			if (character.knowledge == LCK.KNOWLEDGE_KNOWN) then
				found = found + 1 -- Counting researched
			end
			total = total + 1
		elseif (mode == 2 and CharacterKnowledge.GetTradeEligibility(itemLink, itemSource, character.account)) then
			if (character.knowledge == LCK.KNOWLEDGE_UNKNOWN and not character.remaining) then
				local remaining = LCK.CanTraitBeImmediatelyResearchedByCharacter(craftingSkillType, researchLineIndex, traitIndex, nil, character.id)

				-- Handle pending research
				local activeTimeLeft = ""
				if (type(remaining) == "number") then
					activeTimeLeft = string.format(" |c%s(%s)|r", ZO_DEFAULT_DISABLED_COLOR:ToHex(), FormatTimeSecondsEx(remaining, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT))
				end

				if (character.id == CharacterKnowledge.charId) then
					table.insert(results, string.format("|l0:1:1:1:1:ignore|l%s|l%s", character.name, activeTimeLeft))
				else
					table.insert(results, character.name .. activeTimeLeft)
				end

				found = found + 1 -- Counting researchable
			end
			total = total + 1
		end
	end

	return results, found, total
end


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local SCALE = GetUIGlobalScale()
local LINE_WIDTH = zo_ceil(SCALE) / SCALE
local ICON_SIZE = 24
local ICON_SIZE_SMALL = 20
local INDICATOR_OFFSET = 18 -- 75% of ICON_SIZE
local LABEL_SIZE = nil -- To be calculated upon first use
local LABEL_SIZE_MAX = 120
local SPACING_LARGE = 16
local SPACING_SMALL = LINE_WIDTH * 2
local RIGHT_EDGE_OFFSET = -5

local STATE_ACTIVE = 3

local ICONS = {
	BACKGROUND = { 0, 1/16, 0, 0.25 },
	MULTI_INDICATOR = { 0.125, 0.25, 0.5, 1 },
	[LCK.KNOWLEDGE_KNOWN] = { 0.25, 0.5, 0, 1 },
	[LCK.KNOWLEDGE_UNKNOWN] = { 0.5, 0.75, 0, 1 },
	[STATE_ACTIVE] = { 0.75, 1, 0, 1 },
}

local COLORS = {
	BACKGROUND = 0x336666FF,
	HEADER = 0x333333FF,
	[LCK.KNOWLEDGE_KNOWN] = 0x00FF00FF,
	[LCK.KNOWLEDGE_UNKNOWN] = 0xFF0000FF,
	[STATE_ACTIVE] = 0xFFFF00FF,
}


--------------------------------------------------------------------------------
-- ResearchControl
--------------------------------------------------------------------------------

local NextControlId = 1
local ResearchControl = ZO_Object:Subclass()

function ResearchControl:New( list, ... )
	local obj = ZO_Object.New(self)
	obj.id = "CKResearchControl" .. NextControlId
	NextControlId = NextControlId + 1
	obj.list = list
	obj:Initialize(...)
	return obj
end

function ResearchControl:CreateControlFromVirtual( template )
	self.control = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)" .. self.id, self.list.researchFrame, template)
	return self.control
end

function ResearchControl:SetAnchor( ... )
	self.control:SetAnchor(...)
end


--------------------------------------------------------------------------------
-- ResearchLine
--------------------------------------------------------------------------------

local ResearchLine = ResearchControl:Subclass()

do
	local function GridDimension( cells )
		return LINE_WIDTH + (ICON_SIZE + LINE_WIDTH) * cells
	end

	local function AddSurface( control, ... )
		local index = control:AddSurface(...)
		control:SetInsets(index, ...)
		return index
	end

	function ResearchLine:Initialize( craftingSkillType, researchLineIndex )
		self.craftingSkillType = craftingSkillType
		self.researchLineIndex = researchLineIndex

		local name, icon, numTraits = GetSmithingResearchLineInfo(craftingSkillType, researchLineIndex)
		self.name = name
		self.icon = icon
		self.numTraits = numTraits

		-- Controls

		local control = self:CreateControlFromVirtual("CharacterKnowledgeResearchLine")

		local child = control:GetNamedChild("Icon")
		child:SetDimensions(ICON_SIZE, ICON_SIZE)
		child:SetAnchor(TOP)
		child:SetTexture(icon)

		local grid = control:GetNamedChild("Grid")
		grid:SetDimensions(GridDimension(1), GridDimension(numTraits))
		grid:SetAnchor(TOP, child, BOTTOM, nil, SPACING_SMALL)
		self.grid = grid

		child = control:GetNamedChild("Count")
		child:SetDimensions(ICON_SIZE, ICON_SIZE)
		child:SetAnchor(TOP, grid, BOTTOM)
		self.count = child

		-- Surfaces

		local index = AddSurface(grid, 0, 0, 0, 0)
		grid:SetTextureCoords(index, unpack(ICONS.BACKGROUND))
		grid:SetColor(index, LCCC.Int32ToRGBA(COLORS.BACKGROUND))

		self.symbolSurfaces = { }
		self.indicatorSurfaces = { }
		for i = 1, numTraits do
			local top = GridDimension(i - 1)
			local bottom = -GridDimension(numTraits - i)

			index = AddSurface(grid, LINE_WIDTH, -LINE_WIDTH, top, bottom)
			grid:SetTextureCoords(index, unpack(ICONS.BACKGROUND))
			grid:SetColor(index, 0, 0, 0, 1)

			index = AddSurface(grid, LINE_WIDTH, -LINE_WIDTH, top, bottom)
			self.symbolSurfaces[i] = index

			index = AddSurface(grid, LINE_WIDTH + INDICATOR_OFFSET, -LINE_WIDTH, top + INDICATOR_OFFSET, bottom)
			grid:SetTextureCoords(index, unpack(ICONS.MULTI_INDICATOR))
			self.indicatorSurfaces[i] = index
		end

		-- Handlers

		grid:SetHandler("OnMouseEnter", function( )
			EVENT_MANAGER:RegisterForUpdate(self.id, 0, function() self:UpdateTooltip(self:GetMouseOverIndex()) end)
		end)
		grid:SetHandler("OnMouseExit", function( )
			EVENT_MANAGER:UnregisterForUpdate(self.id)
			self:UpdateTooltip(nil)
		end)
	end
end

function ResearchLine:SetTrait( traitIndex, symbolState, multiRatio )
	local grid = self.grid
	local symId = self.symbolSurfaces[traitIndex]
	local indId = self.indicatorSurfaces[traitIndex]

	if (symbolState > 0) then
		grid:SetTextureCoords(symId, unpack(ICONS[symbolState]))
		grid:SetColor(symId, LCCC.Int32ToRGBA(COLORS[symbolState]))
		grid:SetSurfaceHidden(symId, false)
	else
		grid:SetSurfaceHidden(symId, true)
	end

	if (multiRatio < 1) then
		if (CharacterKnowledge.vars.showOthersInResearchGrid == true) then
			grid:SetColor(indId, CharacterKnowledge.GetRatioColorUnpacked(multiRatio))
		else
			local satAlpha = (1 - multiRatio) * 0.8 + 0.2
			grid:SetColor(indId, LCCC.HSLToRGB(0.5, satAlpha , 0.5, satAlpha))
		end
		grid:SetSurfaceHidden(indId, false)
	else
		grid:SetSurfaceHidden(indId, true)
	end
end

function ResearchLine:SetCount( known )
	self.count:SetText(known)
	self.count:SetColor(CharacterKnowledge.GetRatioColorUnpacked(known / self.numTraits))
end

function ResearchLine:GetMouseOverIndex( )
	local grid = self.grid
	for traitIndex, surfaceIndex in pairs(self.symbolSurfaces) do
		local left, right, top, bottom = grid:GetInsets(surfaceIndex)
		if (MouseIsOver(grid, left, top, right, bottom)) then
			return traitIndex
		end
	end
	return nil
end

function ResearchLine:UpdateTooltip( traitIndex )
	if (self.traitIndexShown == traitIndex) then return end
	self.traitIndexShown = traitIndex

	local tooltip = ExtendedJournalTextTooltip
	ClearTooltip(tooltip)

	if (traitIndex) then
		local traitInfo = LCK.GetTraitInfo(self.craftingSkillType, self.researchLineIndex, traitIndex)
		if (traitInfo) then
			LEJ.InitializeTooltip(tooltip)
			tooltip:AddLine(zo_iconTextFormat(traitInfo.icon, "100%", "100%", traitInfo.name), "ZoFontWinH3")
			tooltip:AddLine(zo_iconTextFormat(self.icon, "100%", "100%", self.name), "ZoFontWinH4")
			local results, found, total = CharacterKnowledge.ResearchGetColoredNameList(self.craftingSkillType, self.researchLineIndex, traitIndex, 1, self.list.server, CharacterKnowledge.vars.singleAccount and self.list.account or nil)
			if (#results > 0) then
				local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()
				tooltip:AddLine(table.concat(results, ", "), "LejFontSmall", r, g, b, LEFT, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_LEFT, true)
				tooltip:AddLine(string.format("%d / %d", found, total), "ZoFontWinH5")
			end
		end
	end
end


--------------------------------------------------------------------------------
-- ResearchLabel
--------------------------------------------------------------------------------

local ResearchLabel = ResearchControl:Subclass()

function ResearchLabel:Initialize( textAlign, ... )
	local traitInfo = LCK.GetTraitInfo(...)
	local isLeft = textAlign == TEXT_ALIGN_LEFT

	local control = self:CreateControlFromVirtual("CharacterKnowledgeResearchLabel")

	local icon = control:GetNamedChild("Icon")
	icon:SetDimensions(ICON_SIZE, ICON_SIZE)
	icon:SetAnchor(isLeft and TOPLEFT or TOPRIGHT)
	icon:SetTexture(traitInfo.icon)

	local name = control:GetNamedChild("Name")
	if (not LABEL_SIZE) then
		for _, trait in pairs(LCK.GetTraitList()) do
			LABEL_SIZE = zo_max(name:GetStringWidth(trait.name), LABEL_SIZE or 0)
		end
		LABEL_SIZE = zo_min(LABEL_SIZE / GetUIGlobalScale(), LABEL_SIZE_MAX)
	end
	name:SetDimensions(LABEL_SIZE, ICON_SIZE)
	name:SetAnchor(isLeft and TOPLEFT or TOPRIGHT, icon, isLeft and TOPRIGHT or TOPLEFT, isLeft and SPACING_SMALL or -SPACING_SMALL)
	name:SetHorizontalAlignment(textAlign)
	name:SetText(traitInfo.name)
end


--------------------------------------------------------------------------------
-- ResearchHeader
--------------------------------------------------------------------------------

local ResearchHeader = ResearchControl:Subclass()

function ResearchHeader:Initialize( )
	local control = self:CreateControlFromVirtual("CharacterKnowledgeResearchHeader")

	local bg = control:GetNamedChild("BG")
	bg:SetAnchorFill(control)
	bg:SetColor(LCCC.Int32ToRGBA(COLORS.HEADER))

	local text = control:GetNamedChild("Text")
	text:SetAnchor(TOPLEFT, bg)
	text:SetAnchor(BOTTOMRIGHT, bg, nil, -SPACING_SMALL * 2)
	self.text = text

	control:SetHeight(text:GetFontHeight() + SPACING_SMALL)
end

function ResearchHeader:SetText( ... )
	self.text:SetText(...)
end


--------------------------------------------------------------------------------
-- ResearchItem
--------------------------------------------------------------------------------

local ResearchItem = ResearchControl:Subclass()

function ResearchItem:Initialize( )
	local control = self:CreateControlFromVirtual("CharacterKnowledgeResearchItem")

	local item = control:GetNamedChild("Item")
	item:SetDimensions(ICON_SIZE_SMALL, ICON_SIZE_SMALL)
	item:SetAnchor(TOPRIGHT)
	self.item = item

	local trait = control:GetNamedChild("Trait")
	trait:SetDimensions(ICON_SIZE_SMALL, ICON_SIZE_SMALL)
	trait:SetAnchor(TOPRIGHT, item, TOPLEFT)
	self.trait = trait

	local text = control:GetNamedChild("Text")
	text:SetAnchor(TOPLEFT)
	text:SetAnchor(BOTTOMRIGHT, trait, BOTTOMLEFT, -SPACING_SMALL)
	self.text = text
end

function ResearchItem:SetItem( endTime, ... )
	self.endTime = endTime
	if (endTime) then
		self.item:SetTexture(select(2, GetSmithingResearchLineInfo(...)))
		self.trait:SetTexture(LCK.GetTraitInfo(...).icon)
		self.list.researchTimers[self.id] = self
		self:UpdateTimer()
		self.control:SetHidden(false)
	else
		self.list.researchTimers[self.id] = nil
		self.control:SetHidden(true)
	end
end

function ResearchItem:GetRemainingSeconds( )
	return self.endTime - GetTimeStamp()
end

function ResearchItem:UpdateTimer( )
	self.text:SetText(FormatTimeSecondsEx(self:GetRemainingSeconds(), TIME_FORMAT_STYLE_DAY_AND_COLONS))
end


--------------------------------------------------------------------------------
-- Initialization of Grid UI
--------------------------------------------------------------------------------

function CharacterKnowledgeList:ResearchInitializeAndGetCategoryList( )
	self.RESEARCH_CATEGORY = #LCK.ITEM_CATEGORIES + 1
	self.researchFrame = self.frame:GetNamedChild("Research")
	self.researchFrame:SetHandler("OnEffectivelyHidden", function() self:ResearchUpdateVisibility(false) end)
	self.researchFrame:SetHandler("OnEffectivelyShown", function() self:ResearchUpdateVisibility(true) end)
	return LCCC.MergeTables({ [self.RESEARCH_CATEGORY] = GetString(SI_SMITHING_TAB_RESEARCH) }, LCK.ITEM_CATEGORIES)
end

function CharacterKnowledgeList:ResearchToggleState( )
	local state = self.filterId == self.RESEARCH_CATEGORY
	if (state) then self:ResearchRefresh() end
	self.researchModeIsSelected = state
	self.researchFrame:SetHidden(not state)
	self.headers:SetHidden(state)
	self.frame:GetNamedChild("List"):SetHidden(state)
	self.frame:GetNamedChild("Search"):SetHidden(state)
	return state
end

function CharacterKnowledgeList:ResearchUpdateVisibility( visible )
	self.researchFrameVisible = visible
	self:ResearchCheckTimerState()
end

function CharacterKnowledgeList:ResearchCreateControls( )
	if (self.researchLines) then return end
	self.researchLines = {
		[CRAFTING_TYPE_BLACKSMITHING] = { },
		[CRAFTING_TYPE_CLOTHIER] = { },
		[CRAFTING_TYPE_WOODWORKING] = { },
		[CRAFTING_TYPE_JEWELRYCRAFTING] = { },
	}
	self.researchTimers = { }

	-- The very first call to ResearchLabel:New will probe the necessary width
	-- for this language, hence this initial test label
	local testLabel = ResearchLabel:New(self, TEXT_ALIGN_RIGHT, CRAFTING_TYPE_BLACKSMITHING, 1, 1)

	-- Initial offsets for the grid and labels
	local offsetX = LABEL_SIZE + ICON_SIZE + SPACING_SMALL
	local offsetY = ICON_SIZE + SPACING_SMALL + LINE_WIDTH

	------------------------------------
	-- Grid
	------------------------------------

	local createLine = function( craftingSkillType, researchLineIndex )
		local line = ResearchLine:New(self, craftingSkillType, researchLineIndex)
		self.researchLines[craftingSkillType][researchLineIndex] = line
		return line
	end

	local createLabels = function( line, textAlign, craftingSkillType, researchLineIndex )
		local isLeft = textAlign == TEXT_ALIGN_LEFT
		local label, previousLabel, firstLabel
		for traitIndex = 1, line.numTraits do
			if (craftingSkillType == CRAFTING_TYPE_BLACKSMITHING and researchLineIndex == 1 and traitIndex == 1) then
				label = testLabel -- Reuse the test label from earlier
			else
				label = ResearchLabel:New(self, textAlign, craftingSkillType, researchLineIndex, traitIndex)
			end
			if (traitIndex == 1) then
				label:SetAnchor(isLeft and TOPLEFT or TOPRIGHT, line.control, isLeft and TOPRIGHT or TOPLEFT, isLeft and SPACING_SMALL or -SPACING_SMALL, offsetY)
				firstLabel = label
			else
				label:SetAnchor(TOPLEFT, previousLabel.control, BOTTOMLEFT, nil, LINE_WIDTH)
			end
			previousLabel = label
		end
		return firstLabel
	end

	local previousLine, previousLabel
	local craftingSkillType = CRAFTING_TYPE_BLACKSMITHING
	for researchLineIndex = 1, 7 do
		local line = createLine(craftingSkillType, researchLineIndex)
		if (researchLineIndex == 1) then
			line:SetAnchor(TOPLEFT, nil, nil, offsetX, SPACING_LARGE)
			createLabels(line, TEXT_ALIGN_RIGHT, craftingSkillType, researchLineIndex)
		else
			line:SetAnchor(TOPLEFT, previousLine.control, TOPRIGHT, -LINE_WIDTH)
		end
		previousLine = line
	end

	previousLine = self.researchLines[CRAFTING_TYPE_BLACKSMITHING][1]
	for researchLineIndex = 8, 14 do
		local line = createLine(craftingSkillType, researchLineIndex)
		if (researchLineIndex == 8) then
			line:SetAnchor(TOPLEFT, previousLine.control, BOTTOMLEFT, nil, SPACING_LARGE)
			createLabels(line, TEXT_ALIGN_RIGHT, craftingSkillType, researchLineIndex)
		else
			line:SetAnchor(TOPLEFT, previousLine.control, TOPRIGHT, -LINE_WIDTH)
		end
		previousLine = line
	end

	craftingSkillType = CRAFTING_TYPE_CLOTHIER
	for researchLineIndex = 1, 14 do
		local line = createLine(craftingSkillType, researchLineIndex)
		line:SetAnchor(TOPLEFT, previousLine.control, TOPRIGHT, (researchLineIndex % 7 == 1) and SPACING_LARGE or -LINE_WIDTH)
		previousLine = line
	end

	craftingSkillType = CRAFTING_TYPE_WOODWORKING
	local line = createLine(craftingSkillType, 6)
	line:SetAnchor(TOPLEFT, previousLine.control, TOPRIGHT, SPACING_LARGE)

	previousLine = self.researchLines[CRAFTING_TYPE_BLACKSMITHING][7]
	for researchLineIndex = 1, 5 do
		local line = createLine(craftingSkillType, researchLineIndex)
		line:SetAnchor(TOPLEFT, previousLine.control, TOPRIGHT, (researchLineIndex == 1) and SPACING_LARGE or -LINE_WIDTH)
		previousLine = line
	end

	craftingSkillType = CRAFTING_TYPE_JEWELRYCRAFTING
	for researchLineIndex = 1, 2 do
		local line = createLine(craftingSkillType, researchLineIndex)
		line:SetAnchor(TOPLEFT, previousLine.control, TOPRIGHT, (researchLineIndex == 1) and SPACING_LARGE or -LINE_WIDTH)
		if (researchLineIndex == 2) then
			previousLabel = createLabels(line, TEXT_ALIGN_LEFT, craftingSkillType, researchLineIndex)
		end
		previousLine = line
	end

	------------------------------------
	-- Active Items
	------------------------------------

	self.researchActiveItems = { }

	local anchorActiveItemControl = function( control )
		control:SetAnchor(TOPLEFT, previousLine.control, BOTTOMLEFT)
		control:SetAnchor(TOPRIGHT, previousLine.control, BOTTOMRIGHT, nil, nil, ANCHOR_CONSTRAINS_X)
	end

	for i, craftingSkillType in ipairs(LCK.GetSmithingResearchTradeskillTypes()) do
		local controls = { }
		local header = ResearchHeader:New(self)
		if (i == 1) then
			header:SetAnchor(TOPRIGHT, nil, nil, RIGHT_EDGE_OFFSET, SPACING_LARGE)
			header:SetAnchor(LEFT, previousLabel.control, RIGHT, nil, nil, ANCHOR_CONSTRAINS_X)
		else
			anchorActiveItemControl(header)
		end
		controls.header = header
		previousLine = header

		for j = 1, (craftingSkillType == CRAFTING_TYPE_JEWELRYCRAFTING and 1 or 3) do
			local item = ResearchItem:New(self)
			anchorActiveItemControl(item)
			controls[j] = item
			previousLine = item
		end

		self.researchActiveItems[craftingSkillType] = controls
	end
end


--------------------------------------------------------------------------------
-- Populating the Grid UI
--------------------------------------------------------------------------------

function CharacterKnowledgeList:ResearchRefresh( )
	self:ResearchCreateControls()

	local knownSelf = 0
	local totalSelf = 0

	for _, craftingSkillType in ipairs(LCK.GetSmithingResearchTradeskillTypes()) do
		local activeItems = { }

		for researchLineIndex = 1, GetNumSmithingResearchLines(craftingSkillType) do
			local line = self.researchLines[craftingSkillType][researchLineIndex]
			local knownLine = 0

			for traitIndex = 1, line.numTraits do
				local knowledge, remaining = nil

				local now = GetTimeStamp()
				local knownOthers = 0
				local totalOthers = 0

				if (CharacterKnowledge.vars.showOthersInResearchGrid) then
					for _, character in ipairs(LCK.GetSmithingResearchStatusForCharacters(craftingSkillType, researchLineIndex, traitIndex, self.server, nil, CharacterKnowledge.vars.singleAccount and self.account or nil)) do
						if (character.id == self.charId) then
							knowledge = character.knowledge
							remaining = character.remaining
						else
							if (character.knowledge == LCK.KNOWLEDGE_KNOWN or character.remaining) then
								knownOthers = knownOthers + 1
							end
							totalOthers = totalOthers + 1
						end
					end
				end

				if (knowledge == nil) then
					knowledge, remaining = LCK.GetSmithingResearchStatusForCharacter(craftingSkillType, researchLineIndex, traitIndex, self.server, self.charId)
				end

				if (remaining) then
					if (remaining <= 0) then
						knowledge = LCK.KNOWLEDGE_KNOWN
						remaining = nil
					else
						table.insert(activeItems, { remaining + now, researchLineIndex, traitIndex })
					end
				end

				if (knowledge == LCK.KNOWLEDGE_KNOWN) then
					knownSelf = knownSelf + 1
					knownLine = knownLine + 1
				end
				totalSelf = totalSelf + 1

				line:SetTrait(traitIndex, remaining and STATE_ACTIVE or knowledge, (totalOthers > 0) and knownOthers / totalOthers or 1)
			end

			line:SetCount(knownLine)
		end

		self:ResearchUpdateActiveItems(craftingSkillType, activeItems)
	end

	self:UpdateStatusBarKnownCount(knownSelf, totalSelf)
end

do
	local function ActiveResearchCompare( a, b )
		return a[1] < b[1]
	end

	function CharacterKnowledgeList:ResearchUpdateActiveItems( craftingSkillType, activeItems )
		table.sort(activeItems, ActiveResearchCompare)

		local controls = self.researchActiveItems[craftingSkillType]
		controls.header:SetText(string.format("%s (%d/%d)", GetString("SI_TRADESKILLTYPE", craftingSkillType), #activeItems, LCK.GetMaxSimultaneousSmithingResearchForCharacter(craftingSkillType, self.server, self.charId)))
		for i = 1, #controls do
			local item = activeItems[i]
			if (item) then
				controls[i]:SetItem(item[1], craftingSkillType, item[2], item[3])
			else
				controls[i]:SetItem()
			end
		end

		self:ResearchCheckTimerState()
	end
end

do
	local name = "CKResearchTimerUpdate"
	local active = false

	function CharacterKnowledgeList:ResearchCheckTimerState( )
		if (not active and self.researchFrameVisible and self.researchTimers and next(self.researchTimers)) then
			active = true
			EVENT_MANAGER:RegisterForUpdate("CKResearchTimerUpdate", 1000, function()
				for _, timer in pairs(self.researchTimers) do
					if (timer:GetRemainingSeconds() < -1) then
						return self:ResearchRefresh()
					else
						timer:UpdateTimer()
					end
				end
			end)
		elseif (active and not (self.researchFrameVisible and self.researchTimers and next(self.researchTimers))) then
			active = false
			EVENT_MANAGER:UnregisterForUpdate(name)
		end
	end
end
