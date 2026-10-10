if SPT == nil then SPT = {} end
SPT.AddonName = "WhatsMissing"
SPT.version = 1.0
SPT.active = false
SPT.GUI = {}
local GZNBId, GCCId, GCQI = GetZoneNameById, GetCurrentCharacterId, GetCompletedQuestInfo
local IAchC = IsAchievementComplete
local GS, zf, strF = GetString, zo_strformat, string.format

local LIST_ROW_HEIGHT = 36

-- Tab state: 1=GSP, 2=SQS, 3=GDQ, 4=PD, 5=Skills, 6=Scribing
local TAB_COUNT = 6
local currentTab = 1
local tabGamepadLists = {}
local tabSelectedData = {}
local scan
local progressionList
local progressionModules = { SPT.Skills, SPT.Scribing }

local function SPT_GetProgressionModule()
	return progressionModules[currentTab - 4]
end

local function SPT_CopyArrayTable(origTable)
	if type(origTable) ~= "table" then return origTable end

	local copy = {}
	for key, value in pairs(origTable) do
		if type(value) == "table" then
			local row = {}
			for rowKey, rowValue in pairs(value) do
				row[rowKey] = rowValue
			end
			copy[key] = row
		else
			copy[key] = value
		end
	end
	return copy
end

local function SPT_SortTable(origTable, column)
	if origTable == nil then return {} end
	if type(origTable) ~= "table" then return origTable end

	local sortCol = (type(column) == "number" and column >= 1) and column or 1
	local sortedTable = SPT_CopyArrayTable(origTable)
	table.sort(sortedTable, function(left, right)
		return (left[sortCol] or "") < (right[sortCol] or "")
	end)
	return sortedTable
end

local function SPT_SimpleResetTable(origTable, value)
	if type(origTable) ~= "table" then return value end

	local newTable = {}
	for key, currentValue in pairs(origTable) do
		newTable[key] = SPT_SimpleResetTable(currentValue, value)
	end
	return newTable
end

local function SPT_UpdateInfoPanel(text, title)
	SPT_InfoPanel_Content:SetText(text or "")
	if currentTab > 4 then
		SPT_InfoPanel_Header:SetText(title or GS(currentTab == 5 and SPT_GUI_TAB_SKILLS or SPT_GUI_TAB_SCRIBING))
		SPT_InfoPanel_Header:SetHeight(math.max(36, SPT_InfoPanel_Header:GetTextHeight()))
	else
		SPT_InfoPanel_Header:SetHeight(36)
	end
end

local function SPT_GetCurrentList()
	return tabGamepadLists[currentTab]
end

local function SPT_DeactivateCurrentList()
	local list = SPT_GetCurrentList()
	if list then
		list:Deactivate()
	end
end

local function SPT_ActivateCurrentList()
	if not SPT.active or (scan.running and currentTab <= 4) then return end
	local list = SPT_GetCurrentList()
	if list then
		list:Activate()
		local targetData = list:GetTargetData()
		SPT_UpdateInfoPanel(targetData and targetData.tooltipText or "", targetData and targetData.tooltipTitle)
	end
end

-- Scan state machine
local SCAN_BUDGET_MS = 8
local SCAN_DELAY_MS  = 5
scan = { running = false, dirty = true, phase = 0, index = 0 }


--------------------------------------------------------------------
-- Cross-character cache: account-wide roster + last-scanned snapshot
--------------------------------------------------------------------
-- Storage shape: SPT.savedVars.chars[serverId][charId] = { name, skillPointsInfo }
-- Only the currently active character's skillPointsInfo is ever written (the
-- live API only reflects whoever is logged in); other characters keep
-- whatever was last written the last time THEY were active. The roster
-- (id -> name) is rebuilt every login so deleted characters get pruned and
-- renames stay current, independent of skillPointsInfo.
local SERVER_SHORT_NAMES = {
	["NA Megaserver"] = "NA",
	["EU Megaserver"] = "EU",
}

local function SPT_GetServerId()
	local worldName = GetWorldName()
	return SERVER_SHORT_NAMES[worldName] or worldName
end

local CharCache = {}
SPT.CharCache = CharCache

function CharCache:Init()
	SPT.savedVars = ZO_SavedVars:NewAccountWide("WhatsMissing_CharCache", 1, nil, { chars = {} })
	self.serverId = SPT_GetServerId()
	if not SPT.savedVars.chars[self.serverId] then
		SPT.savedVars.chars[self.serverId] = {}
	end
	self.roster = SPT.savedVars.chars[self.serverId]
	self:Reconcile()
end

-- Always re-queried rather than cached once at Init, since EVENT_ADD_ON_LOADED
-- fires very early in the login sequence and a value captured then is not
-- guaranteed to stay valid/consistent for the rest of the session.
function CharCache:GetCharId()
	return GCCId()
end

-- Re-syncs the roster against the account's current character list. Runs
-- once per login (any character) since that's the only time we can observe
-- deletions/renames/new characters - the character-select screen itself is
-- a separate Lua environment our addon never runs in.
function CharCache:Reconcile()
	local exists = {}
	for i = 1, GetNumCharacters() do
		local name, _, _, _, _, _, id = GetCharacterInfo(i)
		if not self.roster[id] then
			self.roster[id] = {}
		end
		self.roster[id].name = zf("<<1>>", name)
		exists[id] = true
	end
	for id in pairs(self.roster) do
		if not exists[id] then
			self.roster[id] = nil
		end
	end
end

-- Caches the full pd shape (scalars + the ZQ/SS/GD/PD per-row dictionaries),
-- not just totals, so the tab panels can be re-rendered for another
-- character, not only the footer total. Still tiny: ~200 numbers per
-- character, negligible against the memory budget. SPT_CopyArrayTable
-- already does the one-level-deep copy this shape needs.
function CharCache:WriteCurrentSnapshot(pd)
	local charId = self:GetCharId()
	local entry = self.roster[charId]
	if not entry then
		entry = {}
		self.roster[charId] = entry
	end
	local snapshot = SPT_CopyArrayTable(pd)
	snapshot.timestamp = GetTimeStamp()
	if SPT.liveTooltips then
		snapshot.tooltips = SPT_CopyArrayTable(SPT.liveTooltips)
	end
	entry.skillPointsInfo = snapshot
end

-- Returns character ids sorted by name (stable, always available even for
-- characters that have never been scanned). Swapping in a "by missing
-- points" or manually-curated order later only needs a different comparator
-- here.
function CharCache:GetSortedIds()
	local ids = {}
	for id in pairs(self.roster) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return (self.roster[a].name or "") < (self.roster[b].name or "")
	end)
	return ids
end

-- These fields belong to the same per-server roster as the skill-point cache.
function CharCache:WriteProgressionSnapshot(field, snapshot)
	local id = self:GetCharId()
	local entry = self.roster[id]
	if not entry then return end
	entry[field] = snapshot
	entry[field .. "ScannedAt"] = GetTimeStamp()
end

function CharCache:GetClassId(charId)
	for index = 1, GetNumCharacters() do
		local _, _, _, classId, _, _, id = GetCharacterInfo(index)
		if id == charId then return classId end
	end
end

-- Strict independent schema versions; a damaged/unknown snapshot is unscanned.
-- Decode only for the visible view, one character at a time.
function SPT:DecodeProgressionSnapshot(snapshot, paired)
	if type(snapshot) ~= "string" or snapshot:sub(1, 2) ~= "1;" then return end
	local values, offset = {}, 3
	local pattern = paired and "(%d+):(%d+)," or "(%d+),"
	while offset <= #snapshot do
		local first, last, id, value = snapshot:find(pattern, offset)
		if first ~= offset then return end
		id, value = tonumber(id), paired and tonumber(value) or true
		if not id or id < 1 or id > 2147483647 or values[id] ~= nil then return end
		if paired and (not value or value > 2147483647) then return end
		values[id] = value
		offset = last + 1
	end
	return values
end

function SPT:GetProgressionStatus(charId, field, hasData)
	if hasData == false then return GS(SPT_GUI_NOT_SCANNED) end
	if charId == CharCache:GetCharId() then return GS(SPT_GUI_LIVE) end
	local entry = CharCache.roster[charId]
	local timestamp = entry and entry[field .. "ScannedAt"]
	if type(timestamp) ~= "number" then return GS(SPT_GUI_NOT_SCANNED) end
	return GS(SPT_GUI_LAST_SCANNED) .. ": " .. GetDateStringFromTimestamp(timestamp)
end

function SPT:IsProgressionGroupExpanded(module, groupId)
	local groups = self.savedVars.progressionGroups
	local expanded = type(groups) == "table" and groups[module.stateKey]
	return type(expanded) == "table" and expanded[groupId] == true
end

function SPT:SetProgressionGroupExpanded(module, groupId, expanded)
	if type(self.savedVars.progressionGroups) ~= "table" then self.savedVars.progressionGroups = {} end
	local groups = self.savedVars.progressionGroups
	if type(groups[module.stateKey]) ~= "table" then groups[module.stateKey] = {} end
	groups[module.stateKey][groupId] = expanded == true or nil
end

function SPT:FocusCurrentProgressionCharacter()
	local ids, currentId = CharCache:GetSortedIds(), CharCache:GetCharId()
	local first = 1
	for index, id in ipairs(ids) do
		if id == currentId then
			first = math.min(index, math.max(1, #ids - 3))
			break
		end
	end
	for _, module in ipairs(progressionModules) do module.firstCharacter = first end
end

function SPT:ColorCompletedProgression(text, complete)
	return complete and "|c51D878" .. text .. "|r" or text
end

function SPT:FormatProgressionCount(known, total, unknown)
	local hasUnknown = (unknown or 0) > 0
	local text = strF("%d/%d%s", known, total, hasUnknown and " ?" or "")
	return self:ColorCompletedProgression(text, total > 0 and known == total and not hasUnknown)
end

function SPT:AbbreviateCharacterName(name)
	local characters = {}
	for character in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		characters[#characters + 1] = character
	end
	if #characters > 13 then
		local firstWord = name:match("^%s*(%S+)%s+%S")
		if firstWord then return firstWord end
	end
	return table.concat(characters, "", 1, math.min(13, #characters))
end

function SPT:CreateProgressionTableView(module, sourceHeader, footer)
	local ids = CharCache:GetSortedIds()
	module.firstCharacter = math.max(1, math.min(module.firstCharacter or 1, math.max(1, #ids - 3)))
	local last = math.min(module.firstCharacter + 3, #ids)
	local view = { columns = {}, characters = {}, rows = {}, sourceHeader = sourceHeader,
		firstCharacter = module.firstCharacter, characterCount = #ids, footer = footer,
		title = strF(GS(SPT_GUI_CHARACTER_RANGE), #ids > 0 and module.firstCharacter or 0, last, #ids) }
	for index = module.firstCharacter, last do
		local id = ids[index]
		view.characters[#view.characters + 1] = id
		view.columns[#view.columns + 1] = self:AbbreviateCharacterName(CharCache.roster[id].name)
		if id == CharCache:GetCharId() then view.currentCharacterColumn = #view.columns end
	end
	return view
end

function SPT:FinishProgressionTableView(view)
	for _, row in ipairs(view.rows) do
		row.tooltipTitle = row.tooltipTitle or view.infoTitle
		row.tooltipText = row.info and table.concat(row.info, "\n") or row.tooltipText or row.source
		row.info = nil
	end
	return view
end

local function HasScanBudget()
	if GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS then
		local available = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
		if available > 0 then return GetTotalUserAddOnCPUTimeUsedNowMS() + 20 < available end
	end
	return true
end

function SPT:QueueProgressionSnapshot(module, changed)
	if not self.progressionReady then return end
	module.needsFinalCapture = module.needsFinalCapture or changed
	if module.pending then
		-- An event during a slice may have changed a line already read.
		module.rescan = module.rescan or module.capturing
		return
	end
	module.pending = true
	local generation = module.generation
	local capture = coroutine.create(function() module:Capture(coroutine.yield) end)
	local function ContinueCapture()
		if generation ~= module.generation or not SPT.progressionReady then return end
		if not HasScanBudget() then zo_callLater(ContinueCapture, 50); return end
		module.capturing = true
		local started = GetGameTimeMilliseconds()
		for item = 1, 8 do
			local success, message = coroutine.resume(capture)
			if not success then
				module.pending, module.capturing = false, false
				error(message)
			end
			if coroutine.status(capture) == "dead" then
				module.pending, module.capturing = false, false
				if module.rescan then
					module.rescan = false
					SPT:QueueProgressionSnapshot(module, module.needsFinalCapture)
					return
				end
				module.needsFinalCapture = false
				module:ReleaseDisplay()
				if SPT.active and (SPT_GetProgressionModule() == module or (module == SPT.Scribing and currentTab == 1)) then
					SPT:RenderCurrentTab()
				end
				return
			end
			if GetGameTimeMilliseconds() - started >= 4 or not HasScanBudget() then break end
		end
		zo_callLater(ContinueCapture, 16)
	end
	-- Let map/skill initialization settle before starting either snapshot.
	zo_callLater(ContinueCapture, 100)
end

local function SPT_ReleaseProgressionDisplay()
	for _, module in ipairs(progressionModules) do module:ReleaseDisplay() end
	if progressionList then
		progressionList:Clear()
		progressionList:Commit()
	end
	tabSelectedData[5], tabSelectedData[6] = nil, nil
	SPT_GUI_Body_Progression_Title:SetText("")
	SPT_GUI_Body_Progression_Columns_Source:SetText("")
	SPT_GUI_Body_Progression_Columns_AccountTotal:SetText("")
	for index = 1, 4 do
		local header = GetControl("SPT_GUI_Body_Progression_Columns_Cell" .. index)
		header:SetText("")
		header:SetFont("ZoFontGamepad22")
		header:SetColor(1, 1, 1, 1)
	end
	SPT_GUI_Body_Progression_HorizontalScroll:SetHidden(true)
	SPT_UpdateInfoPanel("")
end


-- Static options. Edit these constants to change colors, sorting, and overrides.
SPT.settings = {
	GSP = {
		doneColor = {1, 1, 1},
		needColor = {1, 1, 1},
		progColor = {1, 1, 1},
	},
	SQS = {
		doneColorSS = {1, 1, 1},
		doneColorZQ = {1, 1, 1},
		needColorSS = {1, 0, 0},
		needColorZQ = {1, 0, 0},
		progColorSS = {0.7843, 0.3922, 0},
		progColorZQ = {0.7843, 0.3922, 0},
		sortCol = 1,
	},
	GDQ = {
		doneColor = {1, 1, 1},
		needColor = {1, 0, 0},
		sortCol = 1,
	},
	PDB = {
		doneColor = {1, 1, 1},
		needColor = {1, 0, 0},
		sortCol = 1,
	},
	FD = {
		override = false,
		charHasFD = false,
	},
	TUT = false,
}

-- Transient scan result (never persisted)
SPT.ptsData = {
	Tot	= 0, GenTot	= 0, ZQTot	= 0, numSSTot	= 0, SSTot	= 0,
	GDTot	= 0, PDTot	= 0, Level	= 0, MainQ	= 0, FolDis	= 0,
	tutorial = 0, PvPRank	= 0, MaelAr	= 0, EndlArch	= 0, Unassigned = nil,
	ZQ = {
		AD0 = 0, AD1 = 0, AD2 = 0, AD3 = 0, AD4 = 0, AD5  = 0, DC0a = 0, DC0b = 0,
		DC1 = 0, DC2 = 0, DC3 = 0, DC4 = 0, DC5 = 0, EP0a = 0, EP0b = 0, EP1  = 0,
		EP2 = 0, EP3 = 0, EP4 = 0, EP5 = 0, CH  = 0, CY   = 0,
		CL  = 0, CC  = 0, GC  = 0, IC  = 0, VV   = 0, WR   = 0,
		HB  = 0, SU  = 0, MM  = 0, NE  = 0, WP  = 0, SE   = 0, WS   = 0, TR   = 0,
		BW  = 0, TD  = 0, HI  = 0, GY  = 0, AP  = 0, WW   = 0, SO   = 0,
	},
	SS = {
		AD0 = 0, AD1 = 0, AD2 = 0, AD3 = 0, AD4 = 0, AD5  = 0, DC0a = 0, DC0b = 0,
		DC1 = 0, DC2 = 0, DC3 = 0, DC4 = 0, DC5 = 0, EP0a = 0, EP0b = 0, EP1  = 0,
		EP2 = 0, EP3 = 0, EP4 = 0, EP5 = 0, CH  = 0, CY   = 0, CL   = 0, IC   = 0,
		WR  = 0, HB  = 0, GC  = 0, VV  = 0,
		CC  = 0, WP  = 0, SU  = 0, MM  = 0, NE  = 0, SE   = 0, WS   = 0, TR   = 0,
		BW  = 0, TD  = 0, HI  = 0, GY  = 0, AP  = 0, WW   = 0, SO   = 0,
	},
	GD = {
		BC1 = 0, BC2 = 0, EH1 = 0, EH2 = 0, CA1 = 0, CA2 = 0, TI = 0, SW = 0,
		SC1 = 0, SC2 = 0, WS1 = 0, WS2 = 0, CH1 = 0, CH2 = 0, VF = 0, BH = 0,
		FG1 = 0, FG2 = 0, DC1 = 0, DC2 = 0, AC  = 0, DK  = 0, BC = 0, VM = 0,
		WGT = 0, ICP = 0, RM  = 0, CS  = 0, BF  = 0, FH  = 0, FL = 0, SP = 0,
		MHK = 0, MOS = 0, DoM = 0, FV  = 0, LM  = 0, MF  = 0, IR = 0, UG = 0,
		SG  = 0, CT  = 0, BDV = 0, TC  = 0, RPB = 0, TDC = 0, CA = 0, SR = 0,
		ERE = 0, GD  = 0, BS  = 0, SH  = 0, OP  = 0, BV  = 0, ER = 0, LS = 0,
		NC  = 0, BGF = 0,
	},
	PD = {
		AD1 = 0, AD2 = 0, AD3 = 0, AD4 = 0, AD5 = 0, DC1 = 0, DC2 = 0, DC3 = 0,
		DC4 = 0, DC5 = 0, EP1 = 0, EP2 = 0, EP3 = 0, EP4 = 0, EP5 = 0, CH  = 0,
		VFW = 0, VNC = 0, WOO = 0, WRK = 0, SKW = 0, SSH = 0, RN  = 0, OC  = 0,
		LT  = 0, NK  = 0, SH  = 0, ZA  = 0, GHB = 0, SCC = 0, GO  = 0, TU  = 0,
		LW  = 0, SI  = 0, DG  = 0, CG  = 0,
	},
}

local function SPT_CalculateTotalPoints()
	local quests = 0
	local skyshards = 0
	for _, zi in ipairs(SPT.data.zones) do
		quests = quests + #zi.quests
		if zi.skyshardAchievement then
			zi.skyshards = GetNumSkyshardsInAchievement(zi.skyshardAchievement)
		else
			zi.skyshards = GetNumSkyshardsInZone(SPT.data.ZId.ZN[zi.key])
		end
		skyshards = skyshards + zi.skyshards
	end

	local points = {
		ZQTot = quests,
		numSSTot = skyshards,
		SSTot = math.floor(skyshards / 3),
		GDTot = #SPT.data.GD,
		PDTot = #SPT.data.PD,
		Level = 64,
		MainQ = #SPT.data.MQ,
		FolDis = 2,
		PvPRank = 50,
		MaelAr = 1,
		EndlArch = 1
	}

	local tutorial = 1
	points.GenTot = points.Level + points.MainQ + points.FolDis + tutorial + points.PvPRank + points.MaelAr + points.EndlArch
	points.Tot = points.GenTot + points.GDTot + points.ZQTot + points.SSTot + points.PDTot

	return points
end

local tempZId = {
	ZN = {
		AD0  =  537, AD1  =  381, AD2  =  383, AD3 =  108, AD4 =   58, AD5 =  382,
		DC0a =  535, DC0b =  534, DC1  =    3, DC2 =   19, DC3 =   20, DC4 =  104,
		DC5  =   92, EP0b =  280, EP0a =  281, EP1 =   41, EP2 =   57, EP3 =  117,
		EP4  =  101, EP5  =  103, CH   =  347, CY  =  181, CMT =  181, CL  =  888,
		IC   =  584, WR   =  684, HB   =  816, GC  =  823, VV  =  849, CC  =  980,
		SU   = 1011, MM   =  726, NE   = 1086, WP  =  809, SE  = 1133, WS  = 1160,
		BGC  = 1161, TR   = 1207, BW   = 1261, TD  = 1286, HI  = 1318, GY  = 1383,
		AP   = 1413, TP   = 1414, EA   = 1436, WW  = 1443, SO  = 1502,
	},
}

local zones = {
	{ key = "WP",  quests = {} },
	{ key = "AD0", quests = {} },
	{ key = "AD1", quests = { 4222, 4345, 4261 } },
	{ key = "AD2", quests = { 4868, 4386, 4885 } },
	{ key = "AD3", quests = { 4750, 4765, 4690 } },
	{ key = "AD4", quests = { 4337, 4452, 4143 } },
	{ key = "AD5", quests = { 4712, 4479, 4720 } },
	{ key = "DC0b", quests = {} },
	{ key = "DC0a", quests = {} },
	{ key = "DC1", quests = { 3006, 3235, 3267, 3379 } },
	{ key = "DC2", quests = { 467, 1633, 575 } },
	{ key = "DC3", quests = { 465, 4972, 4884 } },
	{ key = "DC4", quests = { 2192, 2222, 2997 } },
	{ key = "DC5", quests = { 4891, 4912, 4960 } },
	{ key = "EP0b", quests = {} },
	{ key = "EP0a", quests = {} },
	{ key = "EP1", quests = { 3735, 3634, 3868 } },
	{ key = "EP2", quests = { 3797, 3817, 3831 } },
	{ key = "EP3", quests = { 4590, 4606, 3910 } },
	{ key = "EP4", quests = { 4061, 4115, 4117 } },
	{ key = "EP5", quests = { 3968, 4139, 4188 } },
	{ key = "CH",  quests = { 4602, 4730, 4758 } },
	{ key = "CY",  quests = {} },
	{ key = "CL",  quests = {} },
	{ key = "IC",  quests = { 5482 } },
	{ key = "WR",  quests = { 5447, 5468, 5481 } },
	{ key = "HB",  quests = { 5531, 5534, 5532, 5556, 5549, 5545 } },
	{ key = "GC",  quests = { 5540, 5595, 5599, 5596, 5567, 5597, 5598, 5600 } },
	{ key = "VV",  quests = { 6003, 5922, 5948 } },
	{ key = "CC",  quests = { 6050, 6057, 6063, 6025, 6052, 6046, 6047, 6048 } },
	{ key = "SU",  quests = { 6132, 6113, 6126 } },
	{ key = "MM",  quests = { 6246, 6266, 6241, 6259, 6243, 6244, 6245 } },
	{ key = "NE",  quests = { 6336, 6304, 6315 } },
	{ key = "SE",  quests = { 6401, 6409, 6394, 6399, 6403, 6404, 6393, 6397, 6402 } },
	{ key = "WS",  quests = { 6476, 6466, 6481 } },
	{ key = "TR",  quests = { 6550, 6551, 6547, 6548, 6554, 6566, 6552, 6560, 6570 } },
	{ key = "BW",  quests = { 6616, 6619, 6660 } },
	{ key = "TD",  quests = { 6723, 6724, 6707, 6708, 6699, 6700, 6696, 6697, 6693 } },
	{ key = "HI",  quests = { 6753, 6765, 6781, 6762, 6768 } },
	{ key = "GY",  quests = { 6849, 6850, 6855, 6859, 6852, 6853, 6847, 6848, 6894 } },
	{ key = "AP",  quests = { 6971, 6972, 6973, 6974, 6975, 6976, 7025, 6991, 6977 } },
	{ key = "WW",  quests = { 7071, 7072, 7073, 7074, 7075, 7076, 7077, 7078, 7220 } },
	{ key = "SO",  quests = { 7294, 7295, 7296, 7284, 7329, 7285, 7317, 7286, 7393 } },
	{ key = "NV",  quests = {}, name = SPT_GUI_NOWHERE_VAULT, skyshardAchievement = 4657 },
}

SPT.data = {
	ZId = tempZId,
	MAAch = 1304,
	zones = zones,
	tutorials = {
		EO = 6324,
		MO = 5804,
		SO = 6143,
		GO = 6455,
		BO = 6646,
	},
	GD = {
		{ key = "BC1", id = 380,  zone = "AD1",  quest = 4107  },
		{ key = "BC2", id = 935,  zone = "AD1",  quest = 4597  },
		{ key = "EH1", id = 126,  zone = "AD2",  quest = 4336  },
		{ key = "EH2", id = 931,  zone = "AD2",  quest = 4675  },
		{ key = "CA1", id = 176,  zone = "AD3",  quest = 4778  },
		{ key = "CA2", id = 681,  zone = "AD3",  quest = 5120  },
		{ key = "TI",  id = 131,  zone = "AD4",  quest = 4538  },
		{ key = "SW",  id = 31,   zone = "AD5",  quest = 4733  },
		{ key = "SC1", id = 144,  zone = "DC1",  quest = 4054  },
		{ key = "SC2", id = 936,  zone = "DC1",  quest = 4555  },
		{ key = "WS1", id = 146,  zone = "DC2",  quest = 4246  },
		{ key = "WS2", id = 933,  zone = "DC2",  quest = 4813  },
		{ key = "CH1", id = 130,  zone = "DC3",  quest = 4379  },
		{ key = "CH2", id = 932,  zone = "DC3",  quest = 5113  },
		{ key = "VF",  id = 22,   zone = "DC4",  quest = 4432  },
		{ key = "BH",  id = 38,   zone = "DC5",  quest = 4589  },
		{ key = "FG1", id = 283,  zone = "EP1",  quest = 3993  },
		{ key = "FG2", id = 934,  zone = "EP1",  quest = 4303  },
		{ key = "DC1", id = 63,   zone = "EP2",  quest = 4145  },
		{ key = "DC2", id = 930,  zone = "EP2",  quest = 4641  },
		{ key = "AC",  id = 148,  zone = "EP3",  quest = 4202  },
		{ key = "DK",  id = 449,  zone = "EP4",  quest = 4346  },
		{ key = "BC",  id = 64,   zone = "EP5",  quest = 4469  },
		{ key = "VM",  id = 11,   zone = "CH",   quest = 4822  },
		{ key = "ICP", id = 678,  zone = "CY",   quest = 5136  },
		{ key = "WGT", id = 688,  zone = "CY",   quest = 5342  },
		{ key = "CS",  id = 848,  zone = "EP3",  quest = 5702  },
		{ key = "RM",  id = 843,  zone = "EP3",  quest = 5403  },
		{ key = "BF",  id = 973,  zone = "CL",   quest = 5889  },
		{ key = "FH",  id = 974,  zone = "CL",   quest = 5891  },
		{ key = "FL",  id = 1009, zone = "DC5",  quest = 6064  },
		{ key = "SP",  id = 1010, zone = "DC2",  quest = 6065  },
		{ key = "MHK", id = 1052, zone = "AD5",  quest = 6186  },
		{ key = "MOS", id = 1055, zone = "AD3",  quest = 6188  },
		{ key = "DoM", id = 1081, zone = "GC",   quest = 6251  },
		{ key = "FV",  id = 1080, zone = "EP4",  quest = 6249  },
		{ key = "LM",  id = 1123, zone = "AD2",  quest = 6351  },
		{ key = "MF",  id = 1122, zone = "NE",   quest = 6349  },
		{ key = "IR",  id = 1152, zone = "WR",   quest = 6414  },
		{ key = "UG",  id = 1153, zone = "DC5",  quest = 6416  },
		{ key = "SG",  id = 1197, zone = "BGC",  quest = 6505  },
		{ key = "CT",  id = 1201, zone = "WS",   quest = 6507  },
		{ key = "BDV", id = 1228, zone = "GC",   quest = 6576  },
		{ key = "TC",  id = 1229, zone = "EP2",  quest = 6578  },
		{ key = "RPB", id = 1267, zone = "DC1",  quest = 6683  },
		{ key = "TDC", id = 1268, zone = "BW",   quest = 6685  },
		{ key = "CA",  id = 1301, zone = "SU",   quest = 6740  },
		{ key = "SR",  id = 1302, zone = "DC3",  quest = 6742  },
		{ key = "ERE", id = 1360, zone = "HI",   quest = 6835  },
		{ key = "GD",  id = 1361, zone = "HI",   quest = 6837  },
		{ key = "BS",  id = 1389, zone = "EP1",  quest = 6896  },
		{ key = "SH",  id = 1390, zone = "EP5",  quest = 7027  },
		{ key = "OP",  id = 1470, zone = "TR",   quest = 7105  },
		{ key = "BV",  id = 1471, zone = "WR",   quest = 7155  },
		{ key = "ER",  id = 1496, zone = "WW",   quest = 7235  },
		{ key = "LS",  id = 1497, zone = "HB",   quest = 7237  },
		{ key = "NC",  id = 1551, zone = "SO",   quest = 7320  },
		{ key = "BGF", id = 1552, zone = "SO",   quest = 7323  },
	},
	MQ = { 4296, 4831, 4474, 4552, 4607, 4764, 4836, 4837, 4867, 4832, 4847 },
	EA = { 7061 },
	PD = {
		{ key = "AD1", id = 486,  zone = "AD1", achievement = 468  },
		{ key = "AD2", id = 124,  zone = "AD2", achievement = 470  },
		{ key = "AD3", id = 137,  zone = "AD3", achievement = 445  },
		{ key = "AD4", id = 138,  zone = "AD4", achievement = 460  },
		{ key = "AD5", id = 487,  zone = "AD5", achievement = 469  },
		{ key = "DC1", id = 284,  zone = "DC1", achievement = 380  },
		{ key = "DC2", id = 142,  zone = "DC2", achievement = 714  },
		{ key = "DC3", id = 162,  zone = "DC3", achievement = 713  },
		{ key = "DC4", id = 308,  zone = "DC4", achievement = 707  },
		{ key = "DC5", id = 169,  zone = "DC5", achievement = 708  },
		{ key = "EP1", id = 216,  zone = "EP1", achievement = 379  },
		{ key = "EP2", id = 306,  zone = "EP2", achievement = 388  },
		{ key = "EP3", id = 134,  zone = "EP3", achievement = 372  },
		{ key = "EP4", id = 339,  zone = "EP4", achievement = 381  },
		{ key = "EP5", id = 341,  zone = "EP5", achievement = 371  },
		{ key = "CH",  id = 557,  zone = "CH",  achievement = 874  },
		{ key = "VFW", id = 919,  zone = "VV",  achievement = 1855 },
		{ key = "VNC", id = 918,  zone = "VV",  achievement = 1846 },
		{ key = "WOO", id = 706,  zone = "WR",  achievement = 1238 },
		{ key = "WRK", id = 705,  zone = "WR",  achievement = 1235 },
		{ key = "SKW", id = 1020, zone = "SU",  achievement = 2096 },
		{ key = "SSH", id = 1021, zone = "SU",  achievement = 2095 },
		{ key = "RN",  id = 1089, zone = "NE",  achievement = 2444 },
		{ key = "OC",  id = 1090, zone = "NE",  achievement = 2445 },
		{ key = "LT",  id = 1186, zone = "WS",  achievement = 2714 },
		{ key = "NK",  id = 1187, zone = "BGC", achievement = 2715 },
		{ key = "SH",  id = 1260, zone = "BW",  achievement = 2994 },
		{ key = "ZA",  id = 1259, zone = "BW",  achievement = 2995 },
		{ key = "GHB", id = 1338, zone = "HI",  achievement = 3281 },
		{ key = "SCC", id = 1337, zone = "HI",  achievement = 3283 },
		{ key = "GO",  id = 1415, zone = "TP",  achievement = 3658 },
		{ key = "TU",  id = 1416, zone = "AP",  achievement = 3657 },
		{ key = "LW",  id = 1466, zone = "WW",  achievement = 4000 },
		{ key = "SI",  id = 1467, zone = "WW",  achievement = 4002 },
		{ key = "DG",  id = 1514, zone = "SO",  achievement = 4264 },
		{ key = "CG",  id = 1530, zone = "SO",  achievement = 4471 },
	},
}


local function SPT_rgbToHex(rgb)
	local hexStr = '|c'
	for _, v in pairs(rgb) do
		local hex = ''
		local tmpV = math.floor((255 * v) + 0.5)
		while tmpV > 0 do
			local idx = math.fmod(tmpV, 16) + 1
			tmpV = math.floor(tmpV / 16)
			hex = string.sub('0123456789ABCDEF', idx, idx) .. hex
		end
		hex = string.len(hex) == 0 and '00' or (string.len(hex) == 1 and '0' .. hex or hex)
		hexStr = hexStr .. hex
	end
	return hexStr
end

local function FormatQuestName(questName, completed)
	return completed and "|l0:1:0:-25%:2:ffffff|l"..questName.."|l" or questName
end

-- Merges quest chains for a set of skill point quest IDs.
-- A chain is dropped only when it is a strict prefix of another chain (same steps
-- from the start, just shorter) — those are subsumed by the longer chain.
-- Chains that DIVERGE (same root but different path, e.g. Auridon branches) are
-- kept as separate sections.
-- Returns mergedChains (array of chains), spSet (questId -> true for SP quests),
-- and coveredIds (questId -> true for any step appearing in a kept chain).
local function SPT_MergeChains(questIds)
	local spSet  = {}
	local chains = {}
	for _, qid in ipairs(questIds) do
		spSet[qid] = true
		local chain = SPT.chainData and SPT.chainData[qid]
		if chain then table.insert(chains, chain) end
	end

	-- Mark chains that are strict prefixes of a longer chain (dominated).
	local dominated = {}
	for i, a in ipairs(chains) do
		for j, b in ipairs(chains) do
			if i ~= j and #a <= #b and not dominated[i] then
				local isPrefix = true
				for k = 1, #a do
					if a[k].id ~= b[k].id then isPrefix = false; break end
				end
				if isPrefix then dominated[i] = true end
			end
		end
	end

	local mergedChains = {}
	local coveredIds   = {}
	for i, chain in ipairs(chains) do
		if not dominated[i] then
			table.insert(mergedChains, chain)
			for _, step in ipairs(chain) do coveredIds[step.id] = true end
		end
	end
	return mergedChains, spSet, coveredIds
end

local function GetQuestTooltipText(questIds)
	if questIds == nil or #questIds == 0 then return GS(SPT_QUEST_NONE) end
	local mergedChains, spSet = SPT_MergeChains(questIds)
	local SP_ICON = " [SP]"

	-- Render local-start chains first (chain[1] is itself a SP quest for this zone),
	-- then cross-zone chains; within each group, longest chain first so that shared
	-- leading steps are rendered once and trimmed from shorter sibling chains.
	table.sort(mergedChains, function(a, b)
		local aL = spSet[a[1].id] and 1 or 0
		local bL = spSet[b[1].id] and 1 or 0
		if aL ~= bL then return aL > bL end
		return #a > #b
	end)

	local sections = {}
	local shownIds = {}

	for _, chain in ipairs(mergedChains) do
		-- Advance past any leading steps already rendered by an earlier chain
		local startIdx = 1
		while startIdx <= #chain and shownIds[chain[startIdx].id] do
			startIdx = startIdx + 1
		end
		if startIdx <= #chain then
			local lines = {}
			for k = startIdx, #chain do
				local step = chain[k]
				-- Guard mid-chain duplicates (e.g. a shared terminal quest
				-- that appears at the end of multiple diverging chains)
				if not shownIds[step.id] then
					local name   = GetQuestName(step.id)
					local earned = GCQI(step.id) ~= ""
					-- SP_ICON goes AFTER FormatQuestName so it stays outside
					-- the |l...|l link markup used for strikethrough on completed
					-- quests — texture codes don't render inside link tags.
					local line = FormatQuestName(name, earned)
					if spSet[step.id] then line = line .. SP_ICON end
					table.insert(lines, line)
					shownIds[step.id] = true
				end
			end
			if #lines > 0 then
				table.insert(sections, table.concat(lines, "\n"))
			end
		end
	end

	-- Standalone SP quests with no chain data
	for _, questId in ipairs(questIds) do
		if not shownIds[questId] then
			local questName = GetQuestName(questId)
			local earned    = GCQI(questId) ~= ""
			table.insert(sections, FormatQuestName(questName, earned) .. SP_ICON)
		end
	end

	return table.concat(sections, "\n\n")
end

local function GetGDQuestTooltipText(dungeon)
	local questName = GetQuestName(dungeon.quest)
	return FormatQuestName(questName, GCQI(dungeon.quest) ~= "")
end

local function GetSkyshardTooltipText(zone)
	local lines = { GS(SPT_GUI_SKYSHARDS) }
	for index = 1, zone.skyshards do
		local skyshardId = GetAchievementSkyshardId(zone.skyshardAchievement, index)
		local acquired = GetSkyshardDiscoveryStatus(skyshardId) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED
		lines[#lines + 1] = FormatQuestName(GetSkyshardHint(skyshardId), acquired)
	end
	return table.concat(lines, "\n\n")
end

local function GetPDTooltipText(pdung)
	local name = GetAchievementInfo(pdung.achievement)
	return FormatQuestName(name, IAchC(pdung.achievement))
end

local function GetSV(value)
	return value ~= nil and value or 0
end

local function SPT_GetZoneName(zone)
	return zf("<<C:1>>", GZNBId(SPT.data.ZId.ZN[zone]))
end

-- Quest, achievement, and skyshard completion in tooltips is read live
-- from the game API and only ever reflects
-- whoever is actually logged in - it ignores which pd we're rendering from.
-- So when rendering someone other than the live character, we must use
-- their cached tooltip strings (captured the last time THEY were live)
-- instead of recomputing, or we'd silently show the active character's
-- quest progress under another character's name.
--
-- tooltips == nil  : live mode - compute via the game API (pd must be the
--                    live character), and record the results into
--                    SPT.liveTooltips for CharCache to snapshot afterward.
-- tooltips == {}   : no cached tooltip data available - render blank.
-- tooltips == {...}: cached tooltip strings from another character's
--                    snapshot - use them as-is.
local function SPT_UpdateGUITable(pd, tooltips)
	pd = pd or SPT.ptsData
	local live = (tooltips == nil)
	if live then tooltips = { SQS = {}, GDQ = {}, PD = {} } end

	local mqTooltip, eaTooltip
	if live then
		mqTooltip = GetQuestTooltipText(SPT.data.MQ)
		eaTooltip = GetQuestTooltipText(SPT.data.EA)
		tooltips.MQ, tooltips.EA = mqTooltip, eaTooltip
	else
		mqTooltip = tooltips.MQ or ""
		eaTooltip = tooltips.EA or ""
	end

	SPT.GUI = {
		GSP = {
			{ 1, GS(SPT_GUI_CHAR_LEVEL),  GetSV(pd.Level),    SPT.ptsTots.Level,    GS(SPT_QUEST_NA)                    },
			{ 2, GS(SPT_GUI_MAIN_QUEST),  GetSV(pd.MainQ),    SPT.ptsTots.MainQ,    mqTooltip                            },
			{ 3, GS(SPT_GUI_FOLIUM),      GetSV(pd.FolDis),   SPT.ptsTots.FolDis,   GS(SPT_QUEST_NA)                    },
			{ 4, GS(SPT_GUI_TUTORIAL),    GetSV(pd.tutorial), 1,                     ""                                   },
			{ 5, GS(SPT_GUI_AVA_RANK),    GetSV(pd.PvPRank),  SPT.ptsTots.PvPRank,  ""                                   },
			{ 6, GS(SPT_GUI_MAEL_ARENA),  GetSV(pd.MaelAr),   SPT.ptsTots.MaelAr,   ""                                   },
			{ 7, zf("<<t:1>>", GZNBId(SPT.data.ZId.ZN.EA)), GetSV(pd.EndlArch), SPT.ptsTots.EndlArch, eaTooltip },
		},
		GSP_T   = strF("%s: %d/%d", GS(SPT_GUI_TOTAL), pd.GenTot, SPT.ptsTots.GenTot),
		SQS     = {},
		SQS_SL_T = strF("%d/%d", pd.ZQTot, SPT.ptsTots.ZQTot),
		SQS_SS_T = strF("%d/%d", pd.SSTot, SPT.ptsTots.SSTot),
		GDQ     = {},
		GDQ_T   = strF("%s: %d/%d", GS(SPT_GUI_TOTAL), pd.GDTot, SPT.ptsTots.GDTot),
		PDGBE   = {},
		PDGBE_T = strF("%s: %d/%d", GS(SPT_GUI_TOTAL), pd.PDTot, SPT.ptsTots.PDTot),
		CharacterTot = strF("%s: %d/%d  |  %s: %s", GS(SPT_GUI_CHAR_TOTAL), pd.Tot, SPT.ptsTots.Tot,
			GS(SPT_GUI_UNASSIGNED), pd.Unassigned and tostring(pd.Unassigned) or "?"),
	}

	for i, z in ipairs(SPT.data.zones) do
		local text
		if live then
			text = z.skyshardAchievement and GetSkyshardTooltipText(z) or GetQuestTooltipText(z.quests)
			tooltips.SQS[z.key] = text
		else
			text = (tooltips.SQS and tooltips.SQS[z.key]) or ""
		end
		table.insert(SPT.GUI.SQS, {
			i,
			z.name and GS(z.name) or SPT_GetZoneName(z.key),
			GetSV(pd.ZQ[z.key]),
			#z.quests,
			GetSV(pd.SS[z.key]),
			z.skyshards,
			text,
			z.quests,
			z.key,
		})
	end

	for i, d in ipairs(SPT.data.GD) do
		local text
		if live then
			text = GetGDQuestTooltipText(d)
			tooltips.GDQ[d.key] = text
		else
			text = (tooltips.GDQ and tooltips.GDQ[d.key]) or ""
		end
		table.insert(SPT.GUI.GDQ, {
			i,
			zf("<<C:1>>", GZNBId(SPT.data.ZId.ZN[d.zone])),
			zf("<<C:1>>", GZNBId(d.id)),
			GetSV(pd.GD[d.key]),
			text,
		})
	end

	for i, d in ipairs(SPT.data.PD) do
		local text
		if live then
			text = GetPDTooltipText(d)
			tooltips.PD[d.key] = text
		else
			text = (tooltips.PD and tooltips.PD[d.key]) or ""
		end
		table.insert(SPT.GUI.PDGBE, {
			i,
			zf("<<C:1>>", GZNBId(SPT.data.ZId.ZN[d.zone])),
			zf("<<C:1>>", GZNBId(d.id)),
			GetSV(pd.PD[d.key]),
			text,
		})
	end

	if live then
		SPT.liveTooltips = tooltips
	end
end

local function SPT_FormatProgress(current, total, colors)
	if total == 0 then return "-" end
	local color
	if current == 0 then
		color = colors.need
	elseif current == total then
		color = colors.done
	else
		color = colors.progress
	end
	return strF("%s%d/%d|r", color, current, total)
end

local function SPT_AddSeparator(list)
	list:AddEntry("SPT_ListSeparator", { canSelect = false })
end

local function SPT_RefreshListVisuals(list)
	if list and #list.dataList > 0 then
		list:RefreshVisible()
	end
end

local function SPT_IsSelectableData(data)
	return type(data) ~= "table" or data.canSelect ~= false
end

local function SPT_GetSelectablePosition(list, selectedDataIndex)
	local selectedOrdinal = 1
	local totalSelectable = 0

	for dataIndex = 1, #list.dataList do
		if SPT_IsSelectableData(list.dataList[dataIndex]) then
			totalSelectable = totalSelectable + 1
			if dataIndex == selectedDataIndex then
				selectedOrdinal = totalSelectable
			end
		end
	end

	return selectedOrdinal, totalSelectable
end

local function SPT_SetListFixedCenterOffset(list, fixedCenterOffset)
	if list.selectedIndex or list.targetSelectedIndex then
		list:SetFixedCenterOffset(fixedCenterOffset)
	else
		list.fixedCenterOffset = fixedCenterOffset
		list.validGradientDirty = true
	end
end

local function SPT_UpdateListSelectedOffset(list, selectedDataIndex)
	if list and list.control and #list.dataList > 0 then
		local listHeight = list.control:GetHeight()
		if listHeight <= 0 then return end

		local targetIndex = selectedDataIndex or list.targetSelectedIndex or list.selectedIndex or list:CalculateFirstSelectableIndex()
		if not targetIndex then return end

		local selectedOrdinal, totalSelectable = SPT_GetSelectablePosition(list, targetIndex)
		if totalSelectable <= 0 then return end

		local centerTop = math.max(0, (listHeight - LIST_ROW_HEIGHT) / 2)
		local selectedTop = math.min((selectedOrdinal - 1) * LIST_ROW_HEIGHT, centerTop)
		local selectableContentHeight = totalSelectable * LIST_ROW_HEIGHT

		if selectableContentHeight > listHeight then
			local bottomLockedTop = listHeight - ((totalSelectable - selectedOrdinal + 1) * LIST_ROW_HEIGHT)
			selectedTop = math.max(selectedTop, bottomLockedTop)
		end

		selectedTop = math.max(0, math.min(selectedTop, listHeight - LIST_ROW_HEIGHT))
		SPT_SetListFixedCenterOffset(list, -(listHeight / 2) + selectedTop)
	end
end

local function SPT_DisableListFadeGradient(list)
	if list and list.scrollControl and list.scrollControl.SetFadeGradient then
		list.scrollControl:SetFadeGradient(1, 0, 0, 0)
		list.scrollControl:SetFadeGradient(2, 0, 0, 0)
	end
end

local function SPT_CommitList(list)
	SPT_DisableListFadeGradient(list)
	list:Commit()
	if #list.dataList > 0 then
		list:SetFirstIndexSelected()
		SPT_UpdateListSelectedOffset(list)
		tabSelectedData[currentTab] = list:GetTargetData()
		SPT_RefreshListVisuals(list)
	else
		SPT_UpdateInfoPanel("")
	end
end

local function SPT_UpdateListData(list, templateName, data)
	list:Clear()
	if data[1] then
		data[1].canSelect = false
		list:AddEntry(templateName, data[1])
		SPT_AddSeparator(list)
	end
	for i = 2, #data do
		list:AddEntry(templateName, data[i])
	end
	SPT_AddSeparator(list)
	SPT_CommitList(list)
end

local function SPT_RenderGSP()
	local list = tabGamepadLists[1]
	local selected = list:GetTargetData()
	local selectedKey = selected and selected.rowKey
	local GSP_Color = { need = SPT_rgbToHex(SPT.settings.GSP.needColor), progress = SPT_rgbToHex(SPT.settings.GSP.progColor), done = SPT_rgbToHex(SPT.settings.GSP.doneColor) }
	local dataLines = { { header = true, source = GS(SPT_GUI_SOURCE), progress = GS(SPT_GUI_PROGRESS) } }
	for i = 1, #SPT.GUI.GSP do
		local d = {
			rowKey = "general:" .. i,
			source = SPT.GUI.GSP[i][2],
			progress = SPT_FormatProgress(SPT.GUI.GSP[i][3], SPT.GUI.GSP[i][4], GSP_Color),
			tooltipText = SPT.GUI.GSP[i][5],
		}
		table.insert(dataLines, d)
	end
	local charId = SPT:GetViewingCharacterId()
	dataLines[#dataLines + 1] = { rowKey = "scribing:header", source = GS(SPT_GUI_TAB_SCRIBING),
		progress = CharCache.roster[charId] and CharCache.roster[charId].name or "", canSelect = false }
	for _, row in ipairs(SPT.Scribing:BuildSummary(charId)) do dataLines[#dataLines + 1] = row end
	SPT_UpdateListData(list, "SPT_GeneralTemplate", dataLines)
	if selectedKey then
		for index, row in ipairs(list.dataList) do
			if row.rowKey == selectedKey then list:SetSelectedIndexWithoutAnimation(index); break end
		end
	end
	SPT_GUI_Body_GSP_T:SetText(SPT.GUI.GSP_T)
end

local function SPT_RenderSQS()
	local SQS_ColorZQ = { need = SPT_rgbToHex(SPT.settings.SQS.needColorZQ), progress = SPT_rgbToHex(SPT.settings.SQS.progColorZQ), done = SPT_rgbToHex(SPT.settings.SQS.doneColorZQ) }
	local SQS_ColorSS = { need = SPT_rgbToHex(SPT.settings.SQS.needColorSS), progress = SPT_rgbToHex(SPT.settings.SQS.progColorSS), done = SPT_rgbToHex(SPT.settings.SQS.doneColorSS) }
	local tempTable = SPT_SortTable(SPT.GUI.SQS, SPT.settings.SQS.sortCol)
	local list = tabGamepadLists[2]
	local selected = list:GetTargetData()
	local selectedKey = selected and selected.rowKey
	list:Clear()
	for i = 1, #tempTable do
		local d = {
			rowKey      = "zone:" .. tempTable[i][9],
			zone        = tempTable[i][2],
			quests      = SPT_FormatProgress(tempTable[i][3], tempTable[i][4], SQS_ColorZQ),
			skyshards   = SPT_FormatProgress(tempTable[i][5], tempTable[i][6], SQS_ColorSS),
			tooltipText = tempTable[i][7],
			questIds    = tempTable[i][8],
		}
		list:AddEntry("SPT_SQSSTemplate", d)
	end
	SPT_CommitList(list)
	if selectedKey then
		for index, row in ipairs(list.dataList) do
			if row.rowKey == selectedKey then list:SetSelectedIndexWithoutAnimation(index); break end
		end
	end
	SPT_GUI_Body_SQS_SL_T:SetText(SPT.GUI.SQS_SL_T)
	SPT_GUI_Body_SQS_SS_T:SetText(SPT.GUI.SQS_SS_T)
end

local function SPT_RenderGDQ()
	local GDQ_Color = { need = SPT_rgbToHex(SPT.settings.GDQ.needColor), done = SPT_rgbToHex(SPT.settings.GDQ.doneColor) }
	local tempTable = SPT_SortTable(SPT.GUI.GDQ, SPT.settings.GDQ.sortCol)
	local list = tabGamepadLists[3]
	list:Clear()
	for i = 1, #tempTable do
		local d = {
			zone        = tempTable[i][2],
			dungeon     = tempTable[i][3],
			progress    = SPT_FormatProgress(tempTable[i][4], 1, GDQ_Color),
			tooltipText = tempTable[i][5],
		}
		list:AddEntry("SPT_GDQTemplate", d)
	end
	SPT_CommitList(list)
	SPT_GUI_Body_GDQ_T:SetText(SPT.GUI.GDQ_T)
end

local function SPT_RenderPD()
	local PDB_Color = { need = SPT_rgbToHex(SPT.settings.PDB.needColor), done = SPT_rgbToHex(SPT.settings.PDB.doneColor) }
	local tempTable = SPT_SortTable(SPT.GUI.PDGBE, SPT.settings.PDB.sortCol)
	local list = tabGamepadLists[4]
	list:Clear()
	for i = 1, #tempTable do
		local d = {
			zone        = tempTable[i][2],
			dungeon     = tempTable[i][3],
			progress    = SPT_FormatProgress(tempTable[i][4], 1, PDB_Color),
			tooltipText = tempTable[i][5],
		}
		list:AddEntry("SPT_PDGBETemplate", d)
	end
	SPT_CommitList(list)
	SPT_GUI_Body_PD_T:SetText(SPT.GUI.PDGBE_T)
end

local tabRenderers = { SPT_RenderGSP, SPT_RenderSQS, SPT_RenderGDQ, SPT_RenderPD }
local tabBodyControls = {}  -- populated in SetupValues

local function SPT_EnsureProgressionList()
	if progressionList then return end
	progressionList = ZO_GamepadVerticalParametricScrollList:New(SPT_GUI_Body_Progression_ListHolder)
	progressionList:SetUniversalPostPadding(0)
	progressionList:SetSelectedItemOffsets(0, 0)
	SPT_DisableListFadeGradient(progressionList)
	progressionList:AddDataTemplate("SPT_ProgressionTemplate", function(control, data, selected)
		control.data = data
		local source = control:GetNamedChild("_Source")
		source:SetText(data.sourceName or data.source or "")
		source:SetWidth(data.accountTotal and 150 or 250)
		source:SetColor(data.groupId and 0.91 or 1, data.groupId and 0.87 or 1, data.groupId and 0.70 or 1, 1)
		control:GetNamedChild("_AccountTotal"):SetText(data.accountTotal or "")
		for index = 1, 4 do control:GetNamedChild("_Cell" .. index):SetText(data.cells[index] or "") end
		local highlight = control:GetNamedChild("Highlight")
		highlight:SetHidden(not (selected or tabSelectedData[currentTab] == data))
	end, nil, nil, nil, function(control)
		control.data = nil
		control:GetNamedChild("_Source"):SetText("")
		control:GetNamedChild("_Source"):SetWidth(250)
		control:GetNamedChild("_AccountTotal"):SetText("")
		for index = 1, 4 do control:GetNamedChild("_Cell" .. index):SetText("") end
	end)
	progressionList:SetOnTargetDataChangedCallback(function(list, data, _, _, index)
		SPT_UpdateListSelectedOffset(list, index)
		tabSelectedData[currentTab] = data
		SPT_UpdateInfoPanel(data and data.tooltipText or "", data and data.tooltipTitle)
		SPT_RefreshListVisuals(list)
		KEYBIND_STRIP:UpdateKeybindButtonGroup(SPT.keybindDescriptors)
	end)
	progressionList.control:SetHandler("OnRectChanged", function()
		SPT_UpdateListSelectedOffset(progressionList)
		SPT_DisableListFadeGradient(progressionList)
	end)
	SPT_GUI_Body_Progression_Columns:SetHandler("OnMouseWheel", function(_, delta)
		SPT:ScrollProgressionCharacters(-delta)
	end)
	tabGamepadLists[5], tabGamepadLists[6] = progressionList, progressionList
end

local function SPT_RenderProgression()
	SPT_EnsureProgressionList()
	local selected = progressionList:GetTargetData()
	local selectedKey = selected and selected.rowKey
	local view = SPT_GetProgressionModule():BuildView()
	SPT_GUI_Header:SetText(currentTab == 5 and GS(SPT_GUI_TAB_SKILLS) or GS(SPT_GUI_TAB_SCRIBING))
	SPT_InfoPanel_Header:SetText(view.infoTitle)
	SPT_GUI_Body_Progression_Title:SetText(view.title)
	SPT_GUI_Body_Progression_Columns_Source:SetText(view.sourceHeader)
	for index = 1, 4 do
		local header = GetControl("SPT_GUI_Body_Progression_Columns_Cell" .. index)
		local current = index == view.currentCharacterColumn
		header:SetText(view.columns[index] or "")
		header:SetFont(current and "ZoFontGamepadBold22" or "ZoFontGamepad22")
		header:SetColor(current and 0.91 or 1, current and 0.87 or 1, current and 0.70 or 1, 1)
	end
	progressionList:Clear()
	for _, row in ipairs(view.rows) do progressionList:AddEntry("SPT_ProgressionTemplate", row) end
	SPT_CommitList(progressionList)
	if selectedKey then
		for index, row in ipairs(view.rows) do
			if row.rowKey == selectedKey then
				progressionList:SetSelectedIndexWithoutAnimation(index)
				break
			end
		end
	end
	local scroll = SPT_GUI_Body_Progression_HorizontalScroll
	scroll:SetHidden(view.characterCount <= 4)
	if view.characterCount > 4 then
		local thumb = scroll:GetNamedChild("Thumb")
		local width = scroll:GetWidth()
		thumb:SetWidth(width * #view.columns / view.characterCount)
		thumb:ClearAnchors()
		thumb:SetAnchor(LEFT, scroll, LEFT, width * (view.firstCharacter - 1) / view.characterCount, 0)
	end
	SPT_GUI_Footer_CharacterTotal:SetText(view.footer)
end

local function SPT_ShowTabBody(show)
	if not show then
		SPT_DeactivateCurrentList()
	end
	SPT_GUI_Body_GSP:SetHidden(not show or currentTab ~= 1)
	SPT_GUI_Body_SQS:SetHidden(not show or currentTab ~= 2)
	SPT_GUI_Body_GDQ:SetHidden(not show or currentTab ~= 3)
	SPT_GUI_Body_PD:SetHidden(not show or currentTab ~= 4)
	SPT_GUI_Body_Progression:SetHidden(currentTab <= 4)
	SPT_GUI_Scanning:SetHidden(show or currentTab > 4)
end

local function SPT_UpdateTabHighlights()
	for i = 1, TAB_COUNT do
		local tab = GetControl("SPT_GUI_Tabs_Tab"..i)
		if tab then
			if i == currentTab then
				tab:SetColor(1, 1, 1, 1)
			else
				tab:SetColor(0.55, 0.55, 0.55, 1)
			end
		end
	end
end

function SPT:RenderCurrentTab()
	if scan.running and currentTab <= 4 then return end
	SPT_DeactivateCurrentList()
	if currentTab > 4 then
		SPT_GUI_Footer_CharacterTotal:SetFont("ZoFontGamepad22")
		SPT_RenderProgression()
	else
		SPT_GUI_Footer_CharacterTotal:SetFont("ZoFontGamepadBold27")
		SPT_InfoPanel_Header:SetText(GS(SPT_GUI_INFO_HEADER))
		tabRenderers[currentTab]()
		SPT_GUI_Footer_CharacterTotal:SetText(SPT.GUI.CharacterTot)
	end
	SPT_ActivateCurrentList()
end

function SPT:SwitchTab(n)
	SPT_DeactivateCurrentList()
	if currentTab > 4 then SPT_ReleaseProgressionDisplay() end
	currentTab = ((n - 1) % TAB_COUNT) + 1
	SPT_UpdateTabHighlights()
	if currentTab > 4 then
		SPT_ShowTabBody(true)
		SPT:RenderCurrentTab()
	elseif scan.running or scan.dirty then
		SPT_ShowTabBody(false)
		SPT:RefreshSkillPoints()
	else
		SPT_ShowTabBody(true)
		SPT:RefreshViewingDisplay()
	end
	KEYBIND_STRIP:UpdateKeybindButtonGroup(SPT.keybindDescriptors)
end

function SPT:TabPrev()
	if SPT.active then SPT:SwitchTab(currentTab - 1) end
end

function SPT:TabNext()
	if SPT.active then SPT:SwitchTab(currentTab + 1) end
end

function SPT:ScrollToTop()
	local list = SPT_GetCurrentList()
	if SPT.active and list then
		list:SetFirstIndexSelected()
	end
end

function SPT:ScrollToBottom()
	local list = SPT_GetCurrentList()
	if SPT.active and list then
		list:SetLastIndexSelected()
	end
end


-- ─── Cross-character viewing (dpad left/right to switch character) ─────────
-- Lets the player flip through their other characters' last cached totals
-- without leaving the currently active character. Polling dpad state
-- directly via a custom DIRECTIONAL_INPUT consumer is NOT an option - the
-- engine taints the callstack as untrusted the moment it calls into any
-- addon-defined consumer, and IsKeyDown is then refused for the rest of that
-- call chain (confirmed in-game). UI_SHORTCUT_INPUT_LEFT/RIGHT sidesteps
-- that entirely: they're discrete keybind-press slots (same family as the
-- LB/RB/LT/RT bindings below) that happen to be bound to D-Pad Left/Right by
-- default, dispatched through the keybind system rather than raw polling.

local viewingIndex = nil -- index into CharCache:GetSortedIds(); nil = not yet positioned

function SPT:GetViewingCharacterId()
	local ids = CharCache:GetSortedIds()
	return (viewingIndex and ids[viewingIndex]) or CharCache:GetCharId()
end

local function SPT_ResetViewing()
	viewingIndex = nil
end

function SPT:ToggleProgressionGroup()
	local module = SPT_GetProgressionModule()
	local data = progressionList and progressionList:GetTargetData()
	if not module or not data or not data.groupId then return end
	self:SetProgressionGroupExpanded(module, data.groupId, not self:IsProgressionGroupExpanded(module, data.groupId))
	self:RenderCurrentTab()
	KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindDescriptors)
end

function SPT:CanSetScriptWaypoint()
	local data = progressionList and progressionList:GetTargetData()
	return self.active and currentTab == 6 and SPT.Scribing:CanSetPickupWaypoint(data and data.script)
end

function SPT:SetScriptWaypoint()
	if not self:CanSetScriptWaypoint() then return false end
	return SPT.Scribing:SetPickupWaypoint(progressionList:GetTargetData().script)
end

function SPT:CanScrollProgressionCharacters(delta)
	local module = SPT_GetProgressionModule()
	if not module then return false end
	local lastStart = math.max(1, #CharCache:GetSortedIds() - 3)
	local first = module.firstCharacter or 1
	return delta < 0 and first > 1 or delta > 0 and first < lastStart
end

function SPT:ScrollProgressionCharacters(delta)
	if not SPT.active or not self:CanScrollProgressionCharacters(delta) then return end
	local module = SPT_GetProgressionModule()
	module.firstCharacter = math.max(1, math.min((module.firstCharacter or 1) + delta, math.max(1, #CharCache:GetSortedIds() - 3)))
	self:RenderCurrentTab()
	KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindDescriptors)
end

-- A usable cached snapshot must have the full pd shape (ZQ in particular) -
-- guards against entries written by an older version of this addon that
-- only cached totals, which would otherwise crash SPT_UpdateGUITable.
local function SPT_IsUsableSnapshot(info)
	return type(info) == "table" and type(info.ZQ) == "table"
end

-- All-zero pd shape, used so the panels always have *something* consistent
-- to render (rather than leftover rows from whoever was shown previously)
-- when a character has no cached data of their own.
local function SPT_GetEmptyPtsData()
	return SPT_SimpleResetTable(SPT.ptsData, 0)
end

local function SPT_RefreshViewingDisplay()
	if currentTab > 4 then SPT:RenderCurrentTab(); return end
	local ids = SPT.CharCache:GetSortedIds()
	if #ids == 0 then return end

	local selfId = SPT.CharCache:GetCharId()

	if not viewingIndex then
		for i, id in ipairs(ids) do
			if id == selfId then
				viewingIndex = i
				break
			end
		end
		viewingIndex = viewingIndex or 1
	end

	local id = ids[viewingIndex]
	local entry = SPT.CharCache.roster[id]
	local isSelf = (id == selfId)
	local hasData = isSelf or SPT_IsUsableSnapshot(entry.skillPointsInfo)

	-- Always shown, own character included, per request.
	SPT_GUI_Header:SetText(strF("%s - %s", GS(SPT_GUI_PANEL_HEADER), entry.name or "?"))

	-- One consistent render path for all three cases: live data for self,
	-- the cached snapshot for another scanned character, or an empty/zeroed
	-- one if there's nothing cached for them yet - panels never show stale
	-- leftovers from whoever was displayed before. tooltips is passed
	-- explicitly (never nil) except for self, so SPT_UpdateGUITable never
-- falls back to live completion data for someone else.
	local pd, tooltips
	if isSelf then
		pd, tooltips = nil, nil -- SPT_UpdateGUITable defaults to live data
	elseif SPT_IsUsableSnapshot(entry.skillPointsInfo) then
		pd = entry.skillPointsInfo
		tooltips = entry.skillPointsInfo.tooltips or {}
	else
		pd = SPT_GetEmptyPtsData()
		tooltips = {}
	end
	SPT_UpdateGUITable(pd, tooltips)
	SPT:RenderCurrentTab()

	if not hasData then
		SPT_GUI_Footer_CharacterTotal:SetText(strF("%s: %s", entry.name, GS(SPT_GUI_NOT_SCANNED)))
	end
end

function SPT:RefreshViewingDisplay()
	SPT_RefreshViewingDisplay()
end

function SPT:SwitchCharacter(delta)
	if not SPT.active or (scan.running and currentTab <= 4) then return end
	if currentTab > 4 then SPT:ScrollProgressionCharacters(delta); return end
	local ids = SPT.CharCache:GetSortedIds()
	if #ids == 0 then return end

	if not viewingIndex then
		for index, id in ipairs(ids) do if id == CharCache:GetCharId() then viewingIndex = index; break end end
		viewingIndex = viewingIndex or 1
	end
	viewingIndex = ((viewingIndex - 1 + delta) % #ids) + 1
	SPT_RefreshViewingDisplay()
end


-- ─── Scan state machine ────────────────────────────────────────────────────

local function SPT_GetTotSkillPoints()
	local total = SKILL_POINT_ALLOCATION_MANAGER:GetAvailableSkillPoints()
	for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
		for _, skillLineData in ipairs(skillTypeData.orderedSkillLines) do
			total = total + SKILL_POINT_ALLOCATION_MANAGER:GetNumPointsAllocatedInSkillLine(skillLineData)
		end
	end
	return total
end

local function SPT_FinalizeScan()
	local pd = SPT.ptsData

	-- Fix Wailing Prison skyshard (earned but not marked acquired when quest was skipped)
	if pd.SS.WP == 0 and GCQI(SPT.data.MQ[1]) ~= "" then
		pd.SS.WP = 1
		pd.numSSTot = pd.numSSTot + 1
	end
	pd.SSTot = math.floor(pd.numSSTot / 3)

	local skillPoints = SPT_GetTotSkillPoints()
	local counted = pd.Level + pd.MainQ + pd.tutorial + pd.PvPRank + pd.MaelAr +
	                pd.EndlArch + pd.ZQTot + pd.SSTot + pd.GDTot + pd.PDTot

	if SPT.settings.FD.override then
		pd.FolDis = SPT.settings.FD.charHasFD and 2 or 0
	elseif GCQI(3997) ~= "" then
		pd.FolDis = (skillPoints - counted) >= 2 and 2 or 0
	else
		pd.FolDis = 0
	end

	if pd.tutorial == 0 and (skillPoints - counted - pd.FolDis) > 0 then
		pd.tutorial = 1
	end

	pd.GenTot = pd.Level + pd.MainQ + pd.FolDis + pd.tutorial + pd.PvPRank + pd.MaelAr + pd.EndlArch
	pd.Tot    = pd.GenTot + pd.ZQTot + pd.SSTot + pd.GDTot + pd.PDTot

	scan.running = false
	scan.dirty   = false

	SPT_UpdateGUITable() -- also (re)computes SPT.liveTooltips, used right below
	SPT.CharCache:WriteCurrentSnapshot(pd)
	if SPT.active then
		SPT_ShowTabBody(true)
		SPT_RefreshViewingDisplay() -- renders the current tab itself
		KEYBIND_STRIP:UpdateKeybindButtonGroup(SPT.keybindDescriptors)
	end
end

local function ProcessScanSlice()
	if not scan.running then return end
	if not HasScanBudget() then zo_callLater(ProcessScanSlice, 50); return end
	-- Frame time is fixed during a callback; game time advances while Lua runs.
	-- Yield at work-unit boundaries, so 8 ms is a cooperative target, not a hard cap.
	local deadline = GetGameTimeMilliseconds() + SCAN_BUDGET_MS
	local pd = SPT.ptsData

	-- Phase 1: GSP (synchronous — fast enough to do in one shot)
	if scan.phase == 1 then
		local level = GetUnitLevel("player")
		pd.Level    = math.floor(level / 5) + math.floor(level / 10) + (level - 1)
		pd.PvPRank  = GetUnitAvARank("player") or 0
		pd.MaelAr   = IAchC(SPT.data.MAAch) and 1 or 0
		pd.Unassigned = GetAvailableSkillPoints()
		for i = 1, #SPT.data.MQ do
			pd.MainQ = pd.MainQ + ((GCQI(SPT.data.MQ[i]) ~= "") and 1 or 0)
		end
		pd.tutorial = (
			GCQI(SPT.data.tutorials.MO) ~= "" or
			GCQI(SPT.data.tutorials.SO) ~= "" or
			GCQI(SPT.data.tutorials.EO) ~= "" or
			GCQI(SPT.data.tutorials.GO) ~= "" or
			GCQI(SPT.data.tutorials.BO) ~= "" or
			SPT.settings.TUT) and 1 or 0
		pd.EndlArch = (GCQI(SPT.data.EA[1]) ~= "") and 1 or 0
		scan.phase = 2; scan.index = 0
		zo_callLater(ProcessScanSlice, SCAN_DELAY_MS); return
	end

	-- Phase 2: Zone quests (SQS)
	if scan.phase == 2 then
		local zns = SPT.data.zones
		while scan.index < #zns do
			scan.index = scan.index + 1
			local zd = zns[scan.index]
			pd.ZQ[zd.key] = 0
			for i = 1, #zd.quests do
				pd.ZQ[zd.key] = pd.ZQ[zd.key] + ((GCQI(zd.quests[i]) ~= "") and 1 or 0)
			end
			pd.ZQTot = pd.ZQTot + pd.ZQ[zd.key]
			if GetGameTimeMilliseconds() >= deadline or not HasScanBudget() then
				zo_callLater(ProcessScanSlice, SCAN_DELAY_MS); return
			end
		end
		scan.phase = 3; scan.index = 0
	end

	-- Phase 3: Group dungeons
	if scan.phase == 3 then
		local gd = SPT.data.GD
		while scan.index < #gd do
			scan.index = scan.index + 1
			local d = gd[scan.index]
			pd.GD[d.key] = GCQI(d.quest) ~= "" and 1 or 0
			pd.GDTot = pd.GDTot + pd.GD[d.key]
			if GetGameTimeMilliseconds() >= deadline or not HasScanBudget() then
				zo_callLater(ProcessScanSlice, SCAN_DELAY_MS); return
			end
		end
		scan.phase = 4; scan.index = 0
	end

	-- Phase 4: Public dungeons
	if scan.phase == 4 then
		local pdd = SPT.data.PD
		while scan.index < #pdd do
			scan.index = scan.index + 1
			local d = pdd[scan.index]
			pd.PD[d.key] = IAchC(d.achievement) and 1 or 0
			pd.PDTot = pd.PDTot + pd.PD[d.key]
			if GetGameTimeMilliseconds() >= deadline or not HasScanBudget() then
				zo_callLater(ProcessScanSlice, SCAN_DELAY_MS); return
			end
		end
		scan.phase = 5; scan.index = 0
	end

	-- Phase 5: Skyshards
	if scan.phase == 5 then
		local zns = SPT.data.zones
		while scan.index < #zns do
			scan.index = scan.index + 1
			local zd = zns[scan.index]
			local zId = SPT.data.ZId.ZN[zd.key]
			pd.SS[zd.key] = 0
			for i = 1, zd.skyshards do
				-- An achievement can group skyshards across separate room maps.
				-- Discovery status still belongs to the active character.
				local ssId
				if zd.skyshardAchievement then
					ssId = GetAchievementSkyshardId(zd.skyshardAchievement, i)
				else
					ssId = GetZoneSkyshardId(zId, i)
				end
				if GetSkyshardDiscoveryStatus(ssId) == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
					pd.SS[zd.key] = pd.SS[zd.key] + 1
				end
			end
			pd.numSSTot = pd.numSSTot + pd.SS[zd.key]
			if GetGameTimeMilliseconds() >= deadline or not HasScanBudget() then
				zo_callLater(ProcessScanSlice, SCAN_DELAY_MS); return
			end
		end
	end

	SPT_FinalizeScan()
end

local function SPT_StartScan()
	if scan.running then return end
	SPT.ptsData = SPT_SimpleResetTable(SPT.ptsData, 0)
	scan.running = true
	scan.phase   = 1
	scan.index   = 0
	zo_callLater(ProcessScanSlice, 0)
end

function SPT:RefreshSkillPoints()
	SPT_StartScan()
end

local function SPT_MarkDirty()
	scan.dirty = true
	if SPT.active and currentTab <= 4 then
		SPT_ShowTabBody(false)
		SPT_StartScan()
	end
end


-- ─── Item renderers ────────────────────────────────────────────────────────

local function SPT_SetSelectedVisual(control, selected)
	local bg = control:GetNamedChild("Bg")
	if bg then
		bg:SetAlpha(0.2)
		bg:SetColor(1, 1, 1, 1)
	end
	local highlight = control:GetNamedChild("Highlight")
	if highlight then
		highlight:SetHidden(not selected)
		highlight:SetAlpha(selected and 1 or 0)
	end
end

local function SPT_SetLabel(lbl, font, text)
	lbl:SetFont(font); lbl:SetText(text)
end

function SPT:SetupSqsItem(control, data, selected)
	control.data = data
	selected = selected or tabSelectedData[currentTab] == data
	local font = data.header and "ZoFontGamepad34" or "ZoFontGamepad27NoShadow"
	local zone   = control:GetNamedChild("_Zone")
	local ss     = control:GetNamedChild("_Skyshards")
	local quests = control:GetNamedChild("_Quests")
	SPT_SetLabel(zone,   font, data.zone)
	SPT_SetLabel(ss,     font, data.skyshards)
	SPT_SetLabel(quests, font, data.quests)
	SPT_SetSelectedVisual(control, selected)
end

function SPT:SetupGdqItem(control, data, selected)
	control.data = data
	selected = selected or tabSelectedData[currentTab] == data
	local font = data.header and "ZoFontGamepad34" or "ZoFontGamepad27NoShadow"
	local zone     = control:GetNamedChild("_Zone")
	local progress = control:GetNamedChild("_Progress")
	local dungeon  = control:GetNamedChild("_Dungeon")
	SPT_SetLabel(zone,     font, data.zone)
	SPT_SetLabel(dungeon,  font, data.dungeon)
	SPT_SetLabel(progress, font, data.progress)
	SPT_SetSelectedVisual(control, selected)
end

function SPT:SetupGeneralItem(control, data, selected)
	control.data = data
	selected = selected or tabSelectedData[currentTab] == data
	local font = data.header and "ZoFontGamepad34" or "ZoFontGamepad27NoShadow"
	local source   = control:GetNamedChild("_Source")
	local progress = control:GetNamedChild("_Progress")
	SPT_SetLabel(source,   font, data.source)
	SPT_SetLabel(progress, font, data.progress)
	SPT_SetSelectedVisual(control, selected)
end


-- ─── Window & init ─────────────────────────────────────────────────────────

function SPT:ToggleWindow()
	if SPT.active then
		SCENE_MANAGER:Hide("SPT_Scene")
	else
		SCENE_MANAGER:Show("SPT_Scene")
	end
end

local function SPT_IsSkillsMenuEntry(data)
	return data and data.isWhatsMissingSkillPointTracker == true
end

local function SPT_CleanupGamepadSkillsMenu()
	if GAMEPAD_TOOLTIPS then
		GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
		GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
		GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
	end
	if SCENE_MANAGER then
		if SKILLS_ADVISOR_SUGGESTIONS_GAMEPAD_FRAGMENT then
			SCENE_MANAGER:RemoveFragment(SKILLS_ADVISOR_SUGGESTIONS_GAMEPAD_FRAGMENT)
		end
		if GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT then
			SCENE_MANAGER:RemoveFragment(GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT)
		end
	end

	local categoryList = GAMEPAD_SKILLS and GAMEPAD_SKILLS.categoryList
	if not categoryList then return end

	if SPT_IsSkillsMenuEntry(categoryList:GetTargetData()) then
		for index = 1, categoryList:GetNumEntries() do
			local data = categoryList:GetDataForDataIndex(index)
			if data and data.skillLineData then
				categoryList:SetSelectedIndexWithoutAnimation(index)
				break
			end
		end
	end

	if GAMEPAD_SKILLS.DeactivateCurrentList then
		GAMEPAD_SKILLS:DeactivateCurrentList()
	end

	if GAMEPAD_TOOLTIPS then
		GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
		GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
		GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
	end
	if SCENE_MANAGER and GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT then
		SCENE_MANAGER:RemoveFragment(GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT)
	end
end

local function SPT_ShowWindow()
	if SCENE_MANAGER and not SCENE_MANAGER:IsShowing("SPT_Scene") then
		SPT_CleanupGamepadSkillsMenu()
		SCENE_MANAGER:Show("SPT_Scene")
	end
end

function SPT:AddToGamepadSkillsMenu()
	if self.skillsMenuHooked or not ZO_GamepadSkills then return end

	local entryName = "What's Missing?"
	local entryDescription = "Review missing skill points, skill line ranks, and Scribing Scripts across characters."

	ZO_PostHook(ZO_GamepadSkills, "RefreshCategoryList", function(gamepadSkills)
		local categoryList = gamepadSkills and gamepadSkills.categoryList
		if not categoryList then return end

		for index = 1, categoryList:GetNumEntries() do
			if SPT_IsSkillsMenuEntry(categoryList:GetDataForDataIndex(index)) then
				return
			end
		end

		local insertIndex = nil
		for index = 1, categoryList:GetNumEntries() do
			local data = categoryList:GetDataForDataIndex(index)
			if data and data.isSkillsAdvisor then
				insertIndex = index + 1
				break
			end
		end

		local entryData = ZO_GamepadEntryData:New(entryName)
		entryData.isWhatsMissingSkillPointTracker = true
		entryData.advised = true
		if insertIndex then
			categoryList:AddEntryAtIndex(insertIndex, "ZO_GamepadMenuEntryTemplate", entryData)
		else
			categoryList:AddEntry("ZO_GamepadMenuEntryTemplate", entryData)
		end
		categoryList:Commit()
	end)

	ZO_PreHook(ZO_GamepadSkills, "RefreshLineFilterList", function(gamepadSkills)
		local categoryList = gamepadSkills and gamepadSkills.categoryList
		if SPT_IsSkillsMenuEntry(categoryList and categoryList:GetTargetData()) then
			if gamepadSkills.lineFilterList then
				gamepadSkills.lineFilterList:Clear()
				gamepadSkills.lineFilterList:Commit()
			end
			return true
		end
		return false
	end)

	ZO_PreHook(ZO_GamepadSkills, "RefreshTooltip", function(gamepadSkills)
		local categoryList = gamepadSkills and gamepadSkills.categoryList
		if SPT_IsSkillsMenuEntry(categoryList and categoryList:GetTargetData()) then
			GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, entryName, entryDescription)
			return true
		end
		return false
	end)

	ZO_PreHook(ZO_GamepadSkills, "RefreshSelectedTooltip", function(gamepadSkills)
		local categoryList = gamepadSkills and gamepadSkills.categoryList
		if SPT_IsSkillsMenuEntry(categoryList and categoryList:GetTargetData()) then
			GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
			if SKILLS_ADVISOR_SUGGESTIONS_GAMEPAD_FRAGMENT then
				SCENE_MANAGER:RemoveFragment(SKILLS_ADVISOR_SUGGESTIONS_GAMEPAD_FRAGMENT)
			end
			if GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT then
				SCENE_MANAGER:AddFragment(GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT)
			end
			GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, entryName, entryDescription)
			return true
		else
			if GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT then
				SCENE_MANAGER:RemoveFragment(GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT)
			end
		end
		return false
	end)

	local function HookCategoryKeybindDescriptor()
		local descriptor = GAMEPAD_SKILLS and GAMEPAD_SKILLS.categoryKeybindStripDescriptor
		if not descriptor then return end

		for _, keybindDescriptor in ipairs(descriptor) do
			if keybindDescriptor.keybind == "UI_SHORTCUT_PRIMARY" and not keybindDescriptor.sptHooked then
				local originalCallback = keybindDescriptor.callback
				keybindDescriptor.callback = function()
					local categoryList = GAMEPAD_SKILLS and GAMEPAD_SKILLS.categoryList
					if SPT_IsSkillsMenuEntry(categoryList and categoryList:GetTargetData()) then
						if GAMEPAD_SKILLS.DeactivateCurrentList then
							GAMEPAD_SKILLS:DeactivateCurrentList()
						end
						SPT_ShowWindow()
						return
					end
					if originalCallback then
						return originalCallback()
					end
				end
				keybindDescriptor.sptHooked = true
			end

			if keybindDescriptor.keybind == "UI_SHORTCUT_RIGHT_STICK" and not keybindDescriptor.sptHooked then
				local originalCallback = keybindDescriptor.callback
				local originalVisible = keybindDescriptor.visible
				keybindDescriptor.callback = function()
					local categoryList = GAMEPAD_SKILLS and GAMEPAD_SKILLS.categoryList
					if SPT_IsSkillsMenuEntry(categoryList and categoryList:GetTargetData()) then
						return
					end
					if originalCallback then
						return originalCallback()
					end
				end
				keybindDescriptor.visible = function(...)
					local categoryList = GAMEPAD_SKILLS and GAMEPAD_SKILLS.categoryList
					if SPT_IsSkillsMenuEntry(categoryList and categoryList:GetTargetData()) then
						return false
					end
					if originalVisible then
						return originalVisible(...)
					end
					return false
				end
				keybindDescriptor.sptHooked = true
			end
		end
	end

	HookCategoryKeybindDescriptor()
	ZO_PostHook(ZO_GamepadSkills, "InitializeCategoryKeybindStrip", HookCategoryKeybindDescriptor)

	if GAMEPAD_SKILLS and GAMEPAD_SKILLS.categoryList and GAMEPAD_SKILLS.RefreshCategoryList then
		GAMEPAD_SKILLS:RefreshCategoryList()
	end

	self.skillsMenuHooked = true
end

function SPT:SetupValues()

	tabGamepadLists[1] = ZO_GamepadVerticalParametricScrollList:New(SPT_GUI_Body_GSP_ListHolder)
	tabGamepadLists[2] = ZO_GamepadVerticalParametricScrollList:New(SPT_GUI_Body_SQS_ListHolder)
	tabGamepadLists[3] = ZO_GamepadVerticalParametricScrollList:New(SPT_GUI_Body_GDQ_ListHolder)
	tabGamepadLists[4] = ZO_GamepadVerticalParametricScrollList:New(SPT_GUI_Body_PD_ListHolder)

	for i = 1, 4 do
		tabGamepadLists[i]:SetUniversalPostPadding(0)
		tabGamepadLists[i]:SetSelectedItemOffsets(0, 0)
		SPT_UpdateListSelectedOffset(tabGamepadLists[i])
		SPT_DisableListFadeGradient(tabGamepadLists[i])
		tabGamepadLists[i].control:SetHandler("OnRectChanged", function(control)
			SPT_UpdateListSelectedOffset(control.scrollList)
			SPT_DisableListFadeGradient(control.scrollList)
		end)
	end

	tabGamepadLists[1]:AddDataTemplate("SPT_GeneralTemplate", function(c, d, selected) self:SetupGeneralItem(c, d, selected) end)
	tabGamepadLists[2]:AddDataTemplate("SPT_SQSSTemplate",     function(c, d, selected) self:SetupSqsItem(c, d, selected) end)
	tabGamepadLists[3]:AddDataTemplate("SPT_GDQTemplate",      function(c, d, selected) self:SetupGdqItem(c, d, selected) end)
	tabGamepadLists[4]:AddDataTemplate("SPT_PDGBETemplate",    function(c, d, selected) self:SetupGdqItem(c, d, selected) end)

	local function SetupSeparator() end
	local function OnTargetDataChanged(list, targetData)
		-- (nothing extra on row change)
		SPT_UpdateInfoPanel(targetData and targetData.tooltipText or "", targetData and targetData.tooltipTitle)
		KEYBIND_STRIP:UpdateKeybindButtonGroup(SPT.keybindDescriptors)
	end
	for i = 1, 4 do
		local tabIndex = i
		tabGamepadLists[i]:AddDataTemplate("SPT_ListSeparator", SetupSeparator)
		tabGamepadLists[i]:SetOnTargetDataChangedCallback(function(list, targetData, oldTargetData, reachedTarget, targetSelectedIndex)
			SPT_UpdateListSelectedOffset(list, targetSelectedIndex)
			tabSelectedData[tabIndex] = targetData
			OnTargetDataChanged(list, targetData)
			SPT_RefreshListVisuals(list)
		end)
	end

	-- Set initial tab highlight
	SPT_UpdateTabHighlights()

	-- Set fixed column header texts
	SPT_GUI_Body_SQS_ColHeader_ColZone:SetText(GS(SPT_GUI_ZONE))
	SPT_GUI_Body_SQS_ColHeader_ColQuests:SetText(GS(SPT_GUI_STORYLINE))
	SPT_GUI_Body_SQS_ColHeader_ColSkyshards:SetText(GS(SPT_GUI_SKYSHARDS))
	SPT_GUI_Body_GDQ_ColHeader_ColZone:SetText(GS(SPT_GUI_ZONE))
	SPT_GUI_Body_GDQ_ColHeader_ColDungeon:SetText(GS(SPT_GUI_GROUP_DUNGEON))
	SPT_GUI_Body_GDQ_ColHeader_ColProgress:SetText(GS(SPT_GUI_PROGRESS))
	SPT_GUI_Body_PD_ColHeader_ColZone:SetText(GS(SPT_GUI_ZONE))
	SPT_GUI_Body_PD_ColHeader_ColDungeon:SetText(GS(SPT_GUI_PUBLIC_DUNGEON))
	SPT_GUI_Body_PD_ColHeader_ColProgress:SetText(GS(SPT_GUI_PROGRESS))

	-- Keybind strip descriptors. Directional list movement is handled by the active native gamepad list.
	SPT.keybindDescriptors = {
		alignment = KEYBIND_STRIP_ALIGN_LEFT,
		{
			keybind  = "UI_SHORTCUT_LEFT_SHOULDER",
			name     = function() return GS(SI_BINDING_NAME_SPT_TAB_PREV) end,
			callback = function() SPT:SwitchTab(currentTab - 1) end,
			enabled  = function() return true end,
			visible  = function() return true end,
		},
		{
			keybind  = "UI_SHORTCUT_RIGHT_SHOULDER",
			name     = function() return GS(SI_BINDING_NAME_SPT_TAB_NEXT) end,
			callback = function() SPT:SwitchTab(currentTab + 1) end,
			enabled  = function() return true end,
			visible  = function() return true end,
		},
		{
			keybind  = "UI_SHORTCUT_LEFT_TRIGGER",
			name     = "Top",
			callback = function() SPT:ScrollToTop() end,
		},
		{
			keybind  = "UI_SHORTCUT_RIGHT_TRIGGER",
			name     = "Bottom",
			callback = function() SPT:ScrollToBottom() end,
		},
		{
			keybind  = "UI_SHORTCUT_NEGATIVE",
			name     = "Back",
			callback = function() SPT:ToggleWindow() end,
		},
		{
			keybind  = "UI_SHORTCUT_INPUT_LEFT",
			name     = function() return currentTab > 4 and GS(SPT_GUI_SCROLL_LEFT) or "Prev Char" end,
			callback = function() SPT:SwitchCharacter(-1) end,
			visible  = function() return currentTab <= 4 or #CharCache:GetSortedIds() > 4 end,
			enabled  = function() return currentTab <= 4 or SPT:CanScrollProgressionCharacters(-1) end,
		},
		{
			keybind  = "UI_SHORTCUT_INPUT_RIGHT",
			name     = function() return currentTab > 4 and GS(SPT_GUI_SCROLL_RIGHT) or "Next Char" end,
			callback = function() SPT:SwitchCharacter(1) end,
			visible  = function() return currentTab <= 4 or #CharCache:GetSortedIds() > 4 end,
			enabled  = function() return currentTab <= 4 or SPT:CanScrollProgressionCharacters(1) end,
		},
		{
			keybind = "UI_SHORTCUT_PRIMARY",
			name = function()
				local module = SPT_GetProgressionModule()
				local data = progressionList and progressionList:GetTargetData()
				return GS(module and data and data.groupId and SPT:IsProgressionGroupExpanded(module, data.groupId) and SPT_GUI_COLLAPSE or SPT_GUI_EXPAND)
			end,
			callback = function() SPT:ToggleProgressionGroup() end,
			visible = function() return currentTab > 4 end,
			enabled = function() local data = progressionList and progressionList:GetTargetData(); return data and data.groupId ~= nil end,
		},
		{
			keybind = "UI_SHORTCUT_QUATERNARY",
			name = function() return GS(SPT_GUI_SET_SCRIPT_WAYPOINT) end,
			ethHold = true,
			holdDuration = 1000,
			visible = function() return SPT:CanSetScriptWaypoint() end,
			enabled = function() return SPT:CanSetScriptWaypoint() end,
			callback = function() SPT:SetScriptWaypoint() end,
		},
	}

	-- Frame the player on the right side of the screen (panel sits on the left).
	local function SPT_FramingTarget()
		local w, h = GuiRoot:GetDimensions()
		local leftEdge  = 50 + 800   -- left panel right edge
		local rightEdge = w - 50 - 360  -- info panel left edge
		return (leftEdge + rightEdge) / 2, h * 0.55
	end
	local SPT_FRAME_TARGET_FRAGMENT = ZO_NormalizedPointFragment:New(SPT_FramingTarget, SetFrameLocalPlayerTarget)

	-- Create a proper gamepad scene so the keybind strip can intercept controller input
	SPT.scene = ZO_Scene:New("SPT_Scene", SCENE_MANAGER)
	SPT.scene:AddFragment(ZO_FadeSceneFragment:New(SPT_GUI))
	SPT.scene:AddFragment(ZO_FadeSceneFragment:New(SPT_InfoPanel))
	SPT.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
	SPT.scene:AddFragment(SPT_FRAME_TARGET_FRAGMENT)
	SPT.scene:AddFragment(FRAME_TARGET_BLUR_CENTERED_FRAGMENT)
	SPT.scene:AddFragment(FRAME_PLAYER_FRAGMENT)
	SPT.scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
	SPT.scene:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_SHOWING then
			SPT.active = true
			SPT:FocusCurrentProgressionCharacter()
			KEYBIND_STRIP:AddKeybindButtonGroup(SPT.keybindDescriptors)
			if scan.dirty and currentTab <= 4 then
				SPT_ShowTabBody(false)
				SPT_StartScan()
			else
				SPT_ShowTabBody(true)
				SPT_RefreshViewingDisplay() -- renders the current tab itself
			end
		elseif newState == SCENE_HIDDEN then
			SPT.active = false
			SPT_DeactivateCurrentList()
			SPT_ReleaseProgressionDisplay()
			KEYBIND_STRIP:RemoveKeybindButtonGroup(SPT.keybindDescriptors)
			SPT_ResetViewing()
		end
	end)
end

local function SPT_InitSetup()
	SPT.ptsTots = SPT_CalculateTotalPoints()
end

local function SPT_Initialized(eventCode, addonName)

	if addonName ~= SPT.AddonName then return end

	SPT.CharCache:Init()
	SPT_InitSetup()

	SLASH_COMMANDS["/whatsmissing"] = function()
		SPT:ToggleWindow()
	end

	SPT:SetupValues()
	SPT:AddToGamepadSkillsMenu()
	for _, module in ipairs(progressionModules) do module:Init() end
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName .. "Progression", EVENT_PLAYER_ACTIVATED, function()
		SPT.progressionReady = true
		for _, module in ipairs(progressionModules) do SPT:QueueProgressionSnapshot(module) end
	end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName .. "Progression", EVENT_PLAYER_DEACTIVATED, function()
		-- Persist a last-frame learn/rank event before its deferred callback can be lost.
		for _, module in ipairs(progressionModules) do
			if module.needsFinalCapture then module:Capture() end
			module.generation = (module.generation or 0) + 1
			module.pending, module.capturing, module.rescan, module.needsFinalCapture = false, false, false, false
		end
		SPT.progressionReady = false
	end)

	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_SKILL_POINTS_CHANGED,  function() SPT_MarkDirty() end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_SKYSHARDS_UPDATED,      function() SPT_MarkDirty() end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_QUEST_REMOVED,         function(_, isCompleted) if isCompleted then SPT_MarkDirty() end end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_LEVEL_UPDATE,          function(_, unitTag) if unitTag == "player" then SPT_MarkDirty() end end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_ACHIEVEMENT_AWARDED,   function() SPT_MarkDirty() end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_PLAYER_ACTIVATED,      function() SPT_MarkDirty() end)
	EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_PLAYER_DEACTIVATED,    function() scan.dirty = true; scan.running = false end)

	if LibRadialMenu then
		LibRadialMenu:RegisterAddon("SPT", GetString(SPT_GUI_TITLE))
		LibRadialMenu:RegisterEntry(
			"SPT",
			GetString(SI_BINDING_NAME_SPT_TOGGLE),
			"SPT_TOGGLE",
			"esoui/art/zonestories/completionTypeIcon_skyshard.dds",
			function() SPT:ToggleWindow() end,
			GetString(SPT_GUI_TITLE)
		)
	end

	EVENT_MANAGER:UnregisterForEvent(SPT.AddonName, EVENT_ADD_ON_LOADED)
end

-- User lock: prevents other players from running this WIP build
EVENT_MANAGER:RegisterForEvent(SPT.AddonName, EVENT_ADD_ON_LOADED, SPT_Initialized)
