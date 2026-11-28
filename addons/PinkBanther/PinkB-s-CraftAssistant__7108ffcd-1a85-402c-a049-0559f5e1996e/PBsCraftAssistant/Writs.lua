-- Reading the writs out of the quest journal.
--
-- A daily crafting writ is a journal quest of type QUEST_TYPE_CRAFTING. Each line of it ("craft a rubedite helmet",
-- "acquire a rune") is a condition of the main step, of type CRAFT_ITEM or GATHER_ITEM, and the game tells what the
-- line wants as item ids with GetQuestConditionItemInfo -- the same call its own craft advisor uses. A master writ is
-- also a crafting quest, but its line is a CRAFT_RANDOM_WRIT_ITEM condition: such a quest is left alone.
--
-- Scan() fills one reused array of reused records, so reading the journal makes no garbage after the first time.

local A = PBS_CRAFT_ASSIST

A.lines = {} -- the records, 1..A.lineCount valid
A.lineCount = 0

function A:IsCraftingQuest(questIndex)
	if not (questIndex and GetJournalQuestType and QUEST_TYPE_CRAFTING) then
		return false
	end
	return GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING
end

local function IsMasterWrit(questIndex, step, numConditions)
	if not QUEST_CONDITION_TYPE_CRAFT_RANDOM_WRIT_ITEM then
		return false
	end
	for c = 1, numConditions do
		local conditionType = select(8, GetJournalQuestConditionInfo(questIndex, step, c))
		if conditionType == QUEST_CONDITION_TYPE_CRAFT_RANDOM_WRIT_ITEM then
			return true
		end
	end
	return false
end

-- Fill `out` (default A.lines) with the writ lines; with includeDone also the finished ones (the panel shows them).
-- Returns the count. Each record: quest, step, cond, kind ("craft" | "gather"), conditionType, itemId,
-- materialItemId, craftType, quality, cur, max, need (= max - cur), done, text (the journal's line, or nil).
--
-- CRAFT_ITEM and GATHER_ITEM are treated alike, as the game's own craft advisor does: which lines can be crafted is
-- decided by the craft helpers (Craft.lua), not by the condition type. (0.1.0 crafted CRAFT_ITEM lines only and
-- crafted nothing on a PS5 -- the daily lines may well arrive as GATHER_ITEM.) No other filter either: the advisor
-- compares the counters only.
A.scanInfo = { quests = 0, conditions = 0, craft = 0, gather = 0, other = 0, otherType = nil, noItem = 0 }

function A:Scan(out, includeDone)
	out = out or self.lines
	local info = self.scanInfo
	info.quests, info.conditions, info.craft, info.gather, info.other, info.otherType, info.noItem = 0, 0, 0, 0, 0, nil, 0
	local n = 0
	local step = QUEST_MAIN_STEP_INDEX or 1
	local maxQuests = MAX_JOURNAL_QUESTS or 25
	for q = 1, maxQuests do
		if IsValidQuestIndex(q) and self:IsCraftingQuest(q) then
			local numConditions = GetJournalQuestNumConditions(q, step) or 0
			if not IsMasterWrit(q, step, numConditions) then
				info.quests = info.quests + 1
				for c = 1, numConditions do
					local text, cur, max, _, _, _, _, conditionType = GetJournalQuestConditionInfo(q, step, c)
					info.conditions = info.conditions + 1
					local kind = (conditionType == QUEST_CONDITION_TYPE_CRAFT_ITEM and "craft")
						or (conditionType == QUEST_CONDITION_TYPE_GATHER_ITEM and "gather") or nil
					cur, max = tonumber(cur) or 0, tonumber(max) or 0
					if kind == "craft" then
						info.craft = info.craft + 1
					elseif kind == "gather" then
						info.gather = info.gather + 1
					else
						info.other = info.other + 1
						info.otherType = info.otherType or conditionType
					end
					if kind and max > 0 and (includeDone or cur < max) then
						local itemId, materialItemId, craftType, quality = GetQuestConditionItemInfo(q, step, c)
						if itemId and itemId ~= 0 then
							n = n + 1
							local rec = out[n]
							if not rec then
								rec = {}
								out[n] = rec
							end
							rec.quest, rec.step, rec.cond, rec.kind, rec.conditionType = q, step, c, kind, conditionType
							rec.itemId, rec.materialItemId, rec.craftType, rec.quality = itemId, materialItemId or 0, craftType, quality or 0
							rec.cur, rec.max, rec.need, rec.done = cur, max, math.max(0, max - cur), cur >= max
							-- the game's own words for the line (what the journal shows), for the panel
							rec.text = (type(text) == "string" and text ~= "") and text or nil
						else
							info.noItem = info.noItem + 1
						end
					end
				end
			end
		end
	end
	if out == self.lines then
		self.lineCount = n
	end
	return n
end

-- The station a writ line is crafted at. Provisioning is special: the game says which station a recipe belongs to.
function A:StationFor(rec)
	if rec.craftType == CRAFTING_TYPE_PROVISIONING and GetRecipeInfoFromItemId then
		local station = GetRecipeInfoFromItemId(rec.itemId)
		return station or CRAFTING_TYPE_PROVISIONING
	end
	return rec.craftType
end

-- How many crafting writs are in the journal, and how many of them are ready to hand in (all lines done).
function A:CountWrits()
	local total, ready = 0, 0
	local maxQuests = MAX_JOURNAL_QUESTS or 25
	for q = 1, maxQuests do
		if IsValidQuestIndex(q) and self:IsCraftingQuest(q) then
			total = total + 1
			if GetJournalQuestIsComplete and GetJournalQuestIsComplete(q) then
				ready = ready + 1
			end
		end
	end
	return total, ready
end

PBS_CA_MARK("Writs")
