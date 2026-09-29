AffectionMaxxing = AffectionMaxxing or {}
local AM = AffectionMaxxing

AM.name = "AffectionMaxxing"
AM.title = "Affection Maxxing"
AM.version = "1.0.4"

local SAVED_VARIABLES = "AffectionMaxxing_SV"
local CHAT_PREFIX = "|cE8A0C8Affection Maxxing|r: "
-- Most companions named in one suggestion.
local MAX_SUGGESTIONS = 3
-- Auto-summon won't close the same quest's dialog again this soon, in case a summon failed.
local AUTO_SUMMON_RETRY_MS = 30000
-- Time for the conversation to close before summoning.
local SUMMON_DELAY_MS = 250
-- "Companion" is the top rapport status and what companion keepsake achievements need, so
-- companions below it are prioritized over ones already there.
local COMPANION_STATUS_RAPPORT = 4000

local ACCOUNT_DEFAULTS = {
    enabled = true,
    screenAlerts = true,
    readyAlerts = true,
    autoSummon = false,
    minAmount = 10,
    debug = false,
    givers = {}, -- [questId] = NPC the repeatable quest was accepted from
}

-- Companion progress, which NA, EU and PTS track separately, so it's saved per server.
local PROGRESS_DEFAULTS = {
    -- Companion skills are account-wide: [companionId] = { [skill line name] = { rank, maxed } }
    skillLines = {},
}

local CHARACTER_DEFAULTS = {
    rapport = {}, -- [companionId] = last rapport seen while that companion was summoned
    preferredCompanionId = 0, -- 0 means no preferred companion
    preferForSkillXP = false, -- the preferred companion also wins when they'd only gain guild skill XP
}

local lower = zo_strlower or string.lower

local function ContainsPlain(haystack, needle)
    return haystack ~= "" and string.find(lower(haystack), lower(needle), 1, true) ~= nil
end

local function EqualsPlain(a, b)
    return lower(a) == lower(b)
end

local function StartsWithPlain(text, prefix)
    return string.sub(lower(text), 1, #prefix) == lower(prefix)
end

local function FormatName(name)
    if name == nil or name == "" then
        return ""
    end
    return zo_strformat(SI_UNIT_NAME, name)
end

local function JoinNames(names)
    if #names <= 1 then
        return names[1] or ""
    end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

local function WithNote(text, note)
    if note then
        return text .. " " .. note
    end
    return text
end

local function Print(message)
    CHAT_ROUTER:AddSystemMessage(CHAT_PREFIX .. message)
end

function AM:Debug(message)
    if self.account.debug then
        Print("|c888888[debug] " .. message .. "|r")
    end
end

-- Companions --------------------------------------------------------------------------

function AM:KeyForName(name)
    for key, needles in pairs(self.COMPANIONS) do
        for _, needle in ipairs(needles) do
            if ContainsPlain(name, needle) then
                return key
            end
        end
    end
end

function AM:RefreshCompanions()
    self.companions = {} -- [companionId] = { name, collectibleId }
    self.companionIdByKey = {}
    for index = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_COMPANION) do
        local collectibleId = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_COMPANION, index)
        local companionId = GetCollectibleReferenceId(collectibleId)
        local name = FormatName(GetCompanionName(companionId))
        self.companions[companionId] = { name = name, collectibleId = collectibleId }
        local key = self:KeyForName(name)
        if key then
            self.companionIdByKey[key] = companionId
        end
    end
end

function AM:GetSortedCompanionIds()
    local ids = {}
    for companionId in pairs(self.companions) do
        table.insert(ids, companionId)
    end
    table.sort(ids, function(a, b) return self.companions[a].name < self.companions[b].name end)
    return ids
end

-- Whether this character can summon the companion (unlocked and intro quest done).
function AM:IsAvailable(companionId)
    local companion = self.companions[companionId]
    if not companion or not IsCollectibleUnlocked(companion.collectibleId) then
        return false
    end
    local questState = GetCollectibleAssociatedQuestState(companion.collectibleId)
    return questState ~= COLLECTIBLE_ASSOCIATED_QUEST_STATE_INACTIVE
        and questState ~= COLLECTIBLE_ASSOCIATED_QUEST_STATE_ACCEPTED
end

function AM:GetActiveCompanionId()
    if HasActiveCompanion() then
        return GetActiveCompanionDefId()
    end
end

function AM:RecordActiveRapport()
    local companionId = self:GetActiveCompanionId()
    if companionId then
        self.character.rapport[companionId] = GetActiveCompanionRapport()
    end
end

-- The game only exposes the summoned companion's rapport; others come from the cache.
function AM:GetRapport(companionId)
    if companionId == self:GetActiveCompanionId() then
        self:RecordActiveRapport()
    end
    return self.character.rapport[companionId]
end

-- Same test the skills window uses for a maxed XP bar.
local function IsRankMaxed(lastRankXP, nextRankXP)
    return nextRankXP == 0 or nextRankXP == lastRankXP
end

-- Like rapport, skill lines can only be read for the summoned companion.
function AM:RecordActiveSkillLines()
    local companionId = self:GetActiveCompanionId()
    if not companionId or not AreCompanionSkillsInitialized() then
        return
    end
    local lines = {}
    for index = 1, GetNumCompanionSkillLines(SKILL_TYPE_GUILD) do
        local skillLineId = GetCompanionSkillLineId(SKILL_TYPE_GUILD, index)
        local name = zo_strformat(SI_SKILLS_TREE_NAME_FORMAT, GetCompanionSkillLineNameById(skillLineId))
        local rank, _, discovered = GetCompanionSkillLineDynamicInfo(skillLineId)
        local lastRankXP, nextRankXP = GetCompanionSkillLineXPInfo(skillLineId)
        lines[name] = {
            rank = discovered and rank or 0,
            maxed = discovered and IsRankMaxed(lastRankXP, nextRankXP) or false,
        }
    end
    self.progress.skillLines[companionId] = lines
end

function AM:RecordActive()
    self:RecordActiveRapport()
    self:RecordActiveSkillLines()
end

-- Returns the recorded { rank, maxed } and name of a guild skill line, or nil if unknown.
function AM:GetSkillLine(companionId, skillLineName)
    if companionId == self:GetActiveCompanionId() then
        self:RecordActiveSkillLines()
    end
    for name, line in pairs(self.progress.skillLines[companionId] or {}) do
        if ContainsPlain(name, skillLineName) then
            return line, name
        end
    end
end

-- Quests ------------------------------------------------------------------------------

function AM:ReadJournalQuest(journalIndex)
    local questId = GetJournalQuestId(journalIndex)
    local givers = {}
    if self.account.givers[questId] then
        givers[1] = self.account.givers[questId]
    end
    return {
        questId = questId,
        name = GetJournalQuestName(journalIndex),
        questType = GetJournalQuestType(journalIndex),
        repeatType = GetJournalQuestRepeatType(journalIndex),
        givers = givers,
    }
end

local function AnyMatch(values, patterns, matches)
    if not patterns then
        return false
    end
    for _, value in ipairs(values) do
        for _, pattern in ipairs(patterns) do
            if matches(value, pattern) then
                return true
            end
        end
    end
    return false
end

function AM:RuleMatches(rule, quest)
    local hasTextCriteria = rule.givers or rule.names or rule.prefixes
    if not rule.questType and not hasTextCriteria then
        return false
    end
    if rule.questType and rule.questType ~= quest.questType then
        return false
    end
    if not hasTextCriteria then
        return true
    end
    return AnyMatch(quest.givers, rule.givers, ContainsPlain)
        or AnyMatch({ quest.name }, rule.names, EqualsPlain)
        or AnyMatch({ quest.name }, rule.prefixes, StartsWithPlain)
end

-- Returns [companionId] = { amount, note } for every companion who likes this quest.
function AM:FindRapportSources(quest)
    local sources = {}
    if quest.repeatType == QUEST_REPEAT_NOT_REPEATABLE then
        return sources
    end
    local minAmount = self.account.minAmount

    local function Add(companionId, amount, note)
        local existing = sources[companionId]
        if not existing or amount > existing.amount then
            sources[companionId] = { amount = amount, note = note }
        end
    end

    for _, rule in ipairs(self.RULES) do
        if rule.amount >= minAmount and self:RuleMatches(rule, quest) then
            for _, key in ipairs(rule.companions) do
                local companionId = self.companionIdByKey[key]
                if companionId then
                    Add(companionId, rule.amount, rule.note)
                end
            end
        end
    end
    return sources
end

-- Returns the guild skill line this quest levels for any summoned companion, or nil.
function AM:FindSkillLine(quest)
    if quest.repeatType == QUEST_REPEAT_NOT_REPEATABLE then
        return nil
    end
    for _, rule in ipairs(self.RULES) do
        if rule.skillLine and self:RuleMatches(rule, quest) then
            return rule.skillLine
        end
    end
end

-- What a turn-in would give one companion.
function AM:BuildEntry(companionId, source, skillLineName, maxRapport)
    local entry = { id = companionId, name = self.companions[companionId].name }
    if source then
        entry.amount = source.amount
        entry.note = source.note
        entry.rapport = self:GetRapport(companionId)
        entry.gainsRapport = entry.rapport == nil or entry.rapport < maxRapport
    end
    if skillLineName then
        local line, recordedName = self:GetSkillLine(companionId, skillLineName)
        entry.skillLine = line
        entry.skillLineName = recordedName or skillLineName
        entry.gainsSkill = line == nil or not line.maxed
    end
    entry.benefits = entry.gainsRapport or entry.gainsSkill
    return entry
end

local function SkillProgressText(entry)
    local line = entry.skillLine
    if not line then
        return "not recorded yet"
    elseif line.maxed then
        return "max"
    elseif line.rank == 0 then
        return "not started"
    end
    return "rank " .. line.rank
end

local function DescribeCandidate(entry, maxRapport)
    local parts = {}
    if entry.gainsRapport then
        if entry.rapport then
            table.insert(parts, string.format("+%d, %d/%d", entry.amount, entry.rapport, maxRapport))
        else
            table.insert(parts, string.format("+%d, rapport not recorded yet", entry.amount))
        end
    end
    if entry.skillLineName then
        table.insert(parts, entry.skillLineName .. " " .. SkillProgressText(entry))
    end
    return string.format("%s (%s)", entry.name, table.concat(parts, "; "))
end

local function GainText(entry, maxRapport)
    local gains = {}
    if entry.gainsRapport then
        table.insert(gains, string.format("+%d rapport (%d/%d)", entry.amount, entry.rapport, maxRapport))
    end
    if entry.gainsSkill then
        table.insert(gains, string.format("%s XP (%s)", entry.skillLineName, SkillProgressText(entry)))
    end
    return entry.name .. " gains " .. table.concat(gains, " and ") .. "."
end

local function SummonText(candidates, maxRapport)
    local described = {}
    for index = 1, math.min(#candidates, MAX_SUGGESTIONS) do
        described[index] = DescribeCandidate(candidates[index], maxRapport)
    end
    local text = "Summon " .. table.concat(described, " or ") .. " before turning in"
    if #candidates > MAX_SUGGESTIONS then
        text = text .. string.format(" (%d more could also benefit)", #candidates - MAX_SUGGESTIONS)
    end
    return text .. "."
end

local function NeedsCompanionStatus(entry)
    return entry.gainsRapport == true and entry.rapport ~= nil and entry.rapport < COMPANION_STATUS_RAPPORT
end

-- Companions still short of Companion status come first, then others who gain rapport,
-- then those furthest from maxing the skill line.
local function CandidateComparator(maxRapport)
    return function(a, b)
        local aNeeds, bNeeds = NeedsCompanionStatus(a), NeedsCompanionStatus(b)
        if aNeeds ~= bNeeds then
            return aNeeds
        end
        local aRapport, bRapport = a.gainsRapport or false, b.gainsRapport or false
        if aRapport ~= bRapport then
            return aRapport
        end
        if aRapport then
            if a.amount ~= b.amount then
                return a.amount > b.amount
            end
            local aValue, bValue = a.rapport or maxRapport, b.rapport or maxRapport
            if aValue ~= bValue then
                return aValue < bValue
            end
        end
        local aRank = a.skillLine and a.skillLine.rank or math.huge
        local bRank = b.skillLine and b.skillLine.rank or math.huge
        if aRank ~= bRank then
            return aRank < bRank
        end
        return a.name < b.name
    end
end

-- Lower means the companion needs the quest's guild skill line more. Unrecorded ranks sort
-- after recorded ones, maxed lines last.
local UNKNOWN_SKILL_RANK = 1000000
local function SkillNeedRank(entry)
    local line = entry.skillLine
    if not line then
        return UNKNOWN_SKILL_RANK
    elseif line.maxed then
        return math.huge
    end
    return line.rank
end

-- Once everyone the quest helps is at Companion status, skill line need decides.
local function SkillFirstComparator(maxRapport)
    local fallback = CandidateComparator(maxRapport)
    return function(a, b)
        local aRank, bRank = SkillNeedRank(a), SkillNeedRank(b)
        if aRank ~= bRank then
            return aRank < bRank
        end
        return fallback(a, b)
    end
end

local function MaxedLead(entry)
    if entry.amount and entry.skillLineName then
        return string.format("%s is already maxed in rapport and %s.", entry.name, entry.skillLineName)
    elseif entry.skillLineName then
        return string.format("%s is already maxed in %s.", entry.name, entry.skillLineName)
    end
    return entry.name .. " is already at max rapport."
end

-- Returns { kind = "gain" | "warn" | "info", text } or nil when the quest helps nobody.
function AM:Evaluate(quest)
    local sources = self:FindRapportSources(quest)
    local skillLineName = self:FindSkillLine(quest)
    if next(sources) == nil and not skillLineName then
        return nil
    end

    local maxRapport = GetMaximumRapport()
    local activeId = self:GetActiveCompanionId()
    local active
    local candidates = {}
    local maxedNames = {}
    local entries = {}

    -- Guild skill lines help every companion, so a guild quest considers all of them.
    for companionId in pairs(self.companions) do
        local source = sources[companionId]
        local isActive = companionId == activeId
        if (source or skillLineName) and (isActive or self:IsAvailable(companionId)) then
            local entry = self:BuildEntry(companionId, source, skillLineName, maxRapport)
            entries[companionId] = entry
            if isActive then
                active = entry
            elseif entry.benefits then
                table.insert(candidates, entry)
            else
                table.insert(maxedNames, entry.name)
            end
        end
    end
    table.sort(candidates, CandidateComparator(maxRapport))
    table.sort(maxedNames)

    -- A preferred companion who benefits wins, even over a summoned companion who also benefits.
    local character = self.character
    local preferred = entries[character.preferredCompanionId]
    if preferred and (preferred.gainsRapport or (character.preferForSkillXP and preferred.gainsSkill)) then
        if preferred == active then
            return { kind = "gain", text = WithNote(GainText(preferred, maxRapport), preferred.note) }
        end
        local text = "Your preferred companion isn't summoned. " .. SummonText({ preferred }, maxRapport)
        return { kind = "warn", text = WithNote(text, preferred.note), summon = preferred }
    end

    -- Once nobody the quest helps is short of Companion status, whoever needs the guild skill line most wins.
    local someoneNeedsStatus = (active ~= nil and NeedsCompanionStatus(active))
        or (candidates[1] ~= nil and NeedsCompanionStatus(candidates[1]))
    if skillLineName and not someoneNeedsStatus then
        table.sort(candidates, SkillFirstComparator(maxRapport))
        if active and active.benefits then
            local needMore = {}
            if active.skillLine then
                for _, entry in ipairs(candidates) do
                    if entry.skillLine and entry.gainsSkill and SkillNeedRank(entry) < SkillNeedRank(active) then
                        table.insert(needMore, entry)
                    end
                end
            end
            if #needMore > 0 then
                local text = string.format("%s needs %s XP more than %s. %s",
                    needMore[1].name, active.skillLineName, active.name, SummonText(needMore, maxRapport))
                return { kind = "warn", text = WithNote(text, needMore[1].note), summon = needMore[1] }
            end
            return { kind = "gain", text = WithNote(GainText(active, maxRapport), active.note) }
        end
    end

    if active and active.gainsRapport then
        if active.rapport >= COMPANION_STATUS_RAPPORT and candidates[1] and NeedsCompanionStatus(candidates[1]) then
            local needy = {}
            for _, entry in ipairs(candidates) do
                if NeedsCompanionStatus(entry) then
                    table.insert(needy, entry)
                end
            end
            local text = string.format("%s is already at Companion status. %s", active.name, SummonText(needy, maxRapport))
            return { kind = "warn", text = WithNote(text, needy[1].note), summon = needy[1] }
        end
        return { kind = "gain", text = WithNote(GainText(active, maxRapport), active.note) }
    end

    if active and active.gainsSkill then
        local rapportCandidates = {}
        for _, entry in ipairs(candidates) do
            if entry.gainsRapport then
                table.insert(rapportCandidates, entry)
            end
        end
        if #rapportCandidates > 0 then
            local text = string.format("%s would only gain %s XP. %s", active.name, active.skillLineName, SummonText(rapportCandidates, maxRapport))
            return { kind = "warn", text = WithNote(text, rapportCandidates[1].note), summon = rapportCandidates[1] }
        end
        return { kind = "gain", text = GainText(active, maxRapport) }
    end

    if #candidates > 0 then
        local lead
        if active then
            lead = MaxedLead(active)
        elseif activeId then
            lead = "Your summoned companion won't gain rapport from this."
        else
            lead = "No companion is summoned."
        end
        return { kind = "warn", text = WithNote(lead .. " " .. SummonText(candidates, maxRapport), candidates[1].note), summon = candidates[1] }
    end

    if active then
        table.insert(maxedNames, 1, active.name)
    end
    if #maxedNames == 0 then
        return nil
    elseif skillLineName then
        return { kind = "info", text = "All your companions are already maxed for this quest." }
    end
    return { kind = "info", text = JoinNames(maxedNames) .. (#maxedNames == 1 and " is" or " are") .. " already at max rapport." }
end

function AM:Announce(quest, result)
    Print(string.format("|cFFFFFF%s|r: %s", quest.name, result.text))
    if result.kind == "warn" and self.account.screenAlerts then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, quest.name .. ": " .. result.text)
    end
end

-- Auto-summon -------------------------------------------------------------------------

-- Closes the turn-in conversation and summons the companion who benefits most.
-- Returns true if it did, in which case it replaces the usual warning.
function AM:TryAutoSummon(quest, result, npc)
    local entry = result.summon
    if not (self.account.autoSummon and entry) then
        return false
    end
    local talkAgain = string.format("Talk to %s again once they arrive.", npc ~= "" and npc or "the quest giver")
    if HasPendingCompanion() then
        if GetPendingCompanionDefId() ~= entry.id then
            return false
        end
        -- They're already on the way: close the dialog so nothing turns the quest in before they arrive.
        EndInteraction(INTERACTION_CONVERSATION)
        EndInteraction(INTERACTION_QUEST)
        self:Announce(quest, { kind = "warn", text = entry.name .. " is still on the way. " .. talkAgain })
        return true
    end
    local now = GetFrameTimeMilliseconds()
    local lastAttempt = self.autoSummonAttempts[quest.questId]
    if lastAttempt and now - lastAttempt < AUTO_SUMMON_RETRY_MS then
        return false
    end

    -- Check first so a blocked summon (combat, mounted, group full...) doesn't cost you the dialog.
    local collectibleId = self.companions[entry.id].collectibleId
    if IsCollectibleBlocked(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER) then
        local reason = GetCollectibleBlockReason(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        Print(string.format("Can't auto-summon %s: %s", entry.name, zo_strformat(GetString("SI_COLLECTIBLEUSAGEBLOCKREASON", reason))))
        return false
    end
    self.autoSummonAttempts[quest.questId] = now

    EndInteraction(INTERACTION_CONVERSATION)
    EndInteraction(INTERACTION_QUEST)
    zo_callLater(function() UseCollectible(collectibleId, GAMEPLAY_ACTOR_CATEGORY_PLAYER) end, SUMMON_DELAY_MS)

    local text = string.format("Summoning %s. %s", DescribeCandidate(entry, GetMaximumRapport()), talkAgain)
    self:Announce(quest, { kind = "warn", text = text })
    return true
end

-- Auto turn-in addons such as Dolgubon's Lazy Writ Crafter call CompleteQuest() from their own
-- turn-in dialog handler, which can run before or after ours. While auto-summon is on, a turn-in
-- is held until this addon has checked the dialog, then either let through or dropped.
function AM:ShouldBlockCompleteQuest()
    local account, turnIn = self.account, self.turnIn
    if not (account.enabled and account.autoSummon) then
        return false
    end
    if turnIn.blockConversation or turnIn.blockFrame == GetFrameTimeMilliseconds() then
        return true
    end
    if not turnIn.checked then
        turnIn.held = true
        return true
    end
    return false
end

function AM:ResetTurnIn()
    local turnIn = self.turnIn
    turnIn.checked, turnIn.held, turnIn.blockConversation = false, false, false
end

-- Event handlers ----------------------------------------------------------------------

function AM:OnQuestAdded(journalIndex)
    if GetJournalQuestRepeatType(journalIndex) == QUEST_REPEAT_NOT_REPEATABLE then
        return
    end
    local giver = FormatName(GetUnitName("interact"))
    if giver ~= "" then
        self.account.givers[GetJournalQuestId(journalIndex)] = giver
    end
end

function AM:OnQuestCompleteDialog(journalIndex)
    local quest = self:ReadJournalQuest(journalIndex)
    local npc = FormatName(GetUnitName("interact"))
    if npc ~= "" then
        table.insert(quest.givers, npc)
    end
    self:Debug(string.format("turn-in dialog: quest %d \"%s\", type %s, repeat %s, npc \"%s\"",
        quest.questId, quest.name, tostring(quest.questType), tostring(quest.repeatType), npc))

    if not self.account.enabled then
        return
    end
    local turnIn = self.turnIn
    turnIn.checked = true
    self:RefreshCompanions()
    local result = self:Evaluate(quest)
    if result and self:TryAutoSummon(quest, result, npc) then
        -- The dialog is closing for a summon: nothing may turn the quest in first.
        turnIn.blockConversation = true
        turnIn.blockFrame = GetFrameTimeMilliseconds()
        turnIn.held = false
        return
    end
    if result then
        self:Announce(quest, result)
    end
    if result and result.kind == "warn" and self.account.autoSummon then
        -- A better companion couldn't be summoned: leave the turn-in to you, not an auto turn-in addon.
        turnIn.blockFrame = GetFrameTimeMilliseconds()
        turnIn.held = false
    elseif turnIn.held then
        turnIn.held = false
        CompleteQuest()
    end
end

-- Warns once when a quest becomes ready to turn in. Auto turn-in addons (such as Dolgubon's
-- Lazy Writ Crafter) complete the turn-in dialog the moment it opens, too late to react.
function AM:OnQuestProgress(journalIndex)
    local account = self.account
    if not (account.enabled and account.readyAlerts) or not GetJournalQuestIsComplete(journalIndex) then
        return
    end
    local questId = GetJournalQuestId(journalIndex)
    if self.readyWarned[questId] then
        return
    end
    self.readyWarned[questId] = true

    self:RefreshCompanions()
    local quest = self:ReadJournalQuest(journalIndex)
    local result = self:Evaluate(quest)
    if result and result.kind == "warn" then
        self:Announce(quest, { kind = "warn", text = "Ready to turn in. " .. result.text })
    end
end

-- Slash commands ----------------------------------------------------------------------

local function SkillLinesText(lines)
    if not lines then
        return "guild skills not recorded yet"
    end
    local names = {}
    for name in pairs(lines) do
        table.insert(names, name)
    end
    table.sort(names)
    local parts = {}
    for index, name in ipairs(names) do
        parts[index] = name .. " " .. SkillProgressText({ skillLine = lines[name] }):gsub("^rank ", "")
    end
    return table.concat(parts, ", ")
end

function AM:SetPreferredCompanion(text)
    self:RefreshCompanions()
    local character = self.character

    local function Describe(companionId)
        local note = self:IsAvailable(companionId) and ""
            or " They aren't available on this character, so this has no effect until they are."
        return string.format("Preferred companion: %s.%s", self.companions[companionId].name, note)
    end

    if text == "" then
        if self.companions[character.preferredCompanionId] then
            Print(Describe(character.preferredCompanionId))
        else
            Print("No preferred companion. Use /amx prefer <name> to pick one.")
        end
    elseif lower(text) == "none" then
        character.preferredCompanionId = 0
        Print("Preferred companion cleared.")
    else
        for _, companionId in ipairs(self:GetSortedCompanionIds()) do
            if ContainsPlain(self.companions[companionId].name, text) then
                character.preferredCompanionId = companionId
                Print(Describe(companionId))
                return
            end
        end
        Print(string.format("No companion matches \"%s\".", text))
    end
end

function AM:PrintStatus()
    self:RefreshCompanions()
    self:RecordActive()
    local account = self.account
    Print(string.format("%s, auto-summon %s, showing rapport sources of +%d or more. /amx help lists commands.",
        account.enabled and "Enabled" or "Disabled", account.autoSummon and "on" or "off", account.minAmount))

    local ids = self:GetSortedCompanionIds()
    if #ids == 0 then
        Print("  No companions found on this account.")
        return
    end

    local maxRapport = GetMaximumRapport()
    local activeId = self:GetActiveCompanionId()
    for _, companionId in ipairs(ids) do
        local line
        if not self:IsAvailable(companionId) then
            line = "not available on this character"
        else
            local rapport = self:GetRapport(companionId)
            if rapport == nil then
                line = "rapport not recorded yet (summon them once)"
            else
                line = string.format("%d/%d%s", rapport, maxRapport, rapport >= maxRapport and " (max)" or "")
            end
            if companionId == activeId then
                line = line .. ", summoned"
            end
            if companionId == self.character.preferredCompanionId then
                line = line .. ", preferred"
            end
            line = line .. "; " .. SkillLinesText(self.progress.skillLines[companionId])
        end
        Print(string.format("  %s: %s", self.companions[companionId].name, line))
    end
end

function AM:ScanJournal()
    self:RefreshCompanions()
    local found = 0
    for journalIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(journalIndex) then
            local quest = self:ReadJournalQuest(journalIndex)
            local result = self:Evaluate(quest)
            if result then
                found = found + 1
                self:Announce(quest, { kind = "info", text = result.text })
            end
        end
    end
    if found == 0 then
        Print("No quests in your journal give companion rapport or guild skill XP.")
    end
end

function AM:PrintHelp()
    Print("commands (/amx or /affection):")
    Print("  /amx - rapport and guild skill ranks of every companion")
    Print("  /amx settings - open the settings page (needs LibAddonMenu-2.0)")
    Print("  /amx scan - check the quests in your journal")
    Print("  /amx on | off - turn the turn-in warning on or off")
    Print("  /amx alerts - toggle the on-screen alert for warnings")
    Print("  /amx ready - toggle the warning when a quest becomes ready to turn in")
    Print("  /amx autosummon - leave a turn-in with the wrong companion and summon the right one")
    Print("  /amx prefer <name> | none - suggest this companion whenever they'd gain rapport (this character)")
    Print("  /amx preferskill - also prefer them when they'd only gain guild skill XP")
    Print("  /amx min <rapport> - ignore rapport sources worth less (default 10)")
    Print("  /amx debug - toggle debug output")
end

function AM:HandleSlash(argument)
    local command, value = (argument or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = lower(command)
    local account = self.account

    if command == "" or command == "status" then
        self:PrintStatus()
    elseif command == "prefer" then
        self:SetPreferredCompanion(value)
    elseif command == "preferskill" then
        local character = self.character
        character.preferForSkillXP = not character.preferForSkillXP
        Print(character.preferForSkillXP
            and "Your preferred companion also wins when they'd only gain guild skill XP."
            or "Your preferred companion only wins when they'd gain rapport.")
    elseif command == "settings" then
        if self.settingsPanel then
            LibAddonMenu2:OpenToPanel(self.settingsPanel)
        else
            Print("Install LibAddonMenu-2.0 to get a settings page. Every setting is also an /amx command.")
        end
    elseif command == "scan" then
        self:ScanJournal()
    elseif command == "on" or command == "off" then
        account.enabled = command == "on"
        Print(account.enabled and "Turn-in warnings on." or "Turn-in warnings off.")
    elseif command == "alerts" then
        account.screenAlerts = not account.screenAlerts
        Print(account.screenAlerts and "On-screen alerts on." or "On-screen alerts off.")
    elseif command == "ready" then
        account.readyAlerts = not account.readyAlerts
        Print(account.readyAlerts and "Ready-to-turn-in warnings on." or "Ready-to-turn-in warnings off.")
    elseif command == "autosummon" then
        account.autoSummon = not account.autoSummon
        Print(account.autoSummon
            and "Auto-summon on: opening a turn-in with the wrong companion out closes the conversation and summons the right one."
            or "Auto-summon off.")
    elseif command == "min" and tonumber(value) then
        account.minAmount = tonumber(value)
        Print(string.format("Showing rapport sources of +%d or more.", account.minAmount))
    elseif command == "debug" then
        account.debug = not account.debug
        Print(account.debug and "Debug output on." or "Debug output off.")
    else
        self:PrintHelp()
    end
end

-- Settings panel ----------------------------------------------------------------------

local SETTINGS_PANEL_ID = "AffectionMaxxingSettings"

-- Settings > Addons page. It needs the optional LibAddonMenu-2.0; the slash commands
-- change the same saved settings and work without it.
function AM:CreateSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM or self.settingsPanel then
        return
    end
    self.settingsPanel = LAM:RegisterAddonPanel(SETTINGS_PANEL_ID, {
        type = "panel",
        name = self.title,
        author = "TheGodDrums",
        version = self.version,
        website = "https://github.com/tcranor/affectionMaxxingESO",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    local account, character = self.account, self.character
    local function Checkbox(store, key, name, tooltip, default)
        return {
            type = "checkbox",
            name = name,
            tooltip = tooltip,
            default = default,
            getFunc = function() return store[key] end,
            setFunc = function(value) store[key] = value end,
        }
    end

    self:RefreshCompanions()
    local choices, choicesValues = { "None" }, { 0 }
    for _, companionId in ipairs(self:GetSortedCompanionIds()) do
        if self:IsAvailable(companionId) then
            table.insert(choices, self.companions[companionId].name)
            table.insert(choicesValues, companionId)
        end
    end

    LAM:RegisterOptionControls(SETTINGS_PANEL_ID, {
        { type = "header", name = "Warnings" },
        Checkbox(account, "enabled", "Turn-in warnings",
            "In the quest turn-in dialog, say whether your companion gains rapport or guild skill XP, and who to summon instead.", true),
        Checkbox(account, "screenAlerts", "On-screen alerts",
            "Also show warnings as an on-screen alert, not just in chat.", true),
        Checkbox(account, "readyAlerts", "Warn when ready to turn in",
            "Warn once when a quest becomes ready to turn in with the wrong companion out. Useful with addons that auto-complete turn-ins, such as Lazy Writ Crafter.", true),
        {
            type = "slider",
            name = "Minimum rapport",
            tooltip = "Ignore quests worth less rapport than this. The default of 10 hides +5 Thieves Guild jobs and festival writs.",
            min = 5,
            max = 125,
            step = 5,
            default = 10,
            getFunc = function() return account.minAmount end,
            setFunc = function(value) account.minAmount = value end,
        },
        { type = "header", name = "Preferred companion" },
        {
            type = "dropdown",
            name = "Companion",
            tooltip = "This character's preferred companion. Whenever they'd gain rapport from a quest, they're the one suggested and auto-summoned, even if the companion you have out would benefit too.",
            choices = choices,
            choicesValues = choicesValues,
            default = 0,
            getFunc = function() return character.preferredCompanionId end,
            setFunc = function(value) character.preferredCompanionId = value end,
        },
        {
            type = "checkbox",
            name = "Also win for guild skill XP",
            tooltip = "Also prefer them when they're at max rapport but would still gain Fighters Guild, Mages Guild or Undaunted skill XP.",
            default = false,
            disabled = function() return character.preferredCompanionId == 0 end,
            getFunc = function() return character.preferForSkillXP end,
            setFunc = function(value) character.preferForSkillXP = value end,
        },
        { type = "header", name = "Auto-summon" },
        Checkbox(account, "autoSummon", "Auto-summon the right companion",
            "When you open a turn-in with the wrong companion out, close the conversation and summon the companion who benefits most. Talk to the NPC again once they arrive.", false),
        { type = "header", name = "Tools" },
        {
            type = "button",
            name = "Companion status",
            tooltip = "Print every companion's rapport and guild skill ranks to chat.",
            width = "half",
            func = function() self:PrintStatus() end,
        },
        {
            type = "button",
            name = "Scan journal",
            tooltip = "Print which quests in your journal help a companion.",
            width = "half",
            func = function() self:ScanJournal() end,
        },
        Checkbox(account, "debug", "Debug output", "Print quest ID, type and NPC in each turn-in dialog.", false),
    })
end

-- Setup -------------------------------------------------------------------------------

-- Up to 1.0.2, companion skill ranks were saved with the settings, shared by every server.
-- They move to the first server this account logs into, unless that server has its own.
function AM:MoveSkillLinesToServer()
    local old = self.account.skillLines
    if old == nil then
        return
    end
    if next(self.progress.skillLines) == nil then
        self.progress.skillLines = old
    end
    self.account.skillLines = nil
end

function AM:Initialize()
    -- Settings follow the account to every server. Character IDs differ between servers, so
    -- per-character data can't collide. Companion skill ranks are saved per server.
    self.account = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES, 1, nil, ACCOUNT_DEFAULTS)
    self.character = ZO_SavedVars:NewCharacterIdSettings(SAVED_VARIABLES, 1, nil, CHARACTER_DEFAULTS)
    self.progress = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES, 1, "Progress", PROGRESS_DEFAULTS, GetWorldName())
    self:MoveSkillLinesToServer()
    self.readyWarned = {} -- [questId] = true once warned that it's ready to turn in
    self.autoSummonAttempts = {} -- [questId] = frame time of the last auto-summon for it
    self.turnIn = {} -- whether the open turn-in dialog was checked, see ShouldBlockCompleteQuest

    local name = self.name
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        self:RecordActive()
        -- Built once in the world, so the preferred companion list matches this character.
        self:CreateSettingsPanel()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMPANION_ACTIVATED, function() self:RecordActive() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMPANION_RAPPORT_UPDATE, function(_, companionId, _, currentRapport)
        self.character.rapport[companionId] = currentRapport
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMPANION_SKILLS_FULL_UPDATE, function() self:RecordActiveSkillLines() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COMPANION_SKILL_RANK_UPDATE, function() self:RecordActiveSkillLines() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_ADDED, function(_, journalIndex) self:OnQuestAdded(journalIndex) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_COMPLETE_DIALOG, function(_, journalIndex) self:OnQuestCompleteDialog(journalIndex) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_ADVANCED, function(_, journalIndex) self:OnQuestProgress(journalIndex) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, function(_, journalIndex) self:OnQuestProgress(journalIndex) end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CHATTER_BEGIN, function() self:ResetTurnIn() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_CHATTER_END, function() self:ResetTurnIn() end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_QUEST_REMOVED, function(_, _, _, _, _, _, questId)
        self.readyWarned[questId] = nil
        -- The next turn-in in this conversation needs its own check.
        self.turnIn.checked = false
    end)

    local function HandleSlash(argument) self:HandleSlash(argument) end
    SLASH_COMMANDS["/amx"] = HandleSlash
    SLASH_COMMANDS["/affection"] = HandleSlash

    ZO_PreHook("CompleteQuest", function() return self:ShouldBlockCompleteQuest() end)
end

EVENT_MANAGER:RegisterForEvent(AM.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName == AM.name then
        EVENT_MANAGER:UnregisterForEvent(AM.name, EVENT_ADD_ON_LOADED)
        AM:Initialize()
    end
end)
