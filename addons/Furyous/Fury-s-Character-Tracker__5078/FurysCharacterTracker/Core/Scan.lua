-- Reads the character you are logged in on: skill lines, skill points, research, scribing, motifs, recipes,
-- furnishing plans, riding, companions, time played. Runs at login and a few seconds after
-- any progress (a rank up, a trait finished, a recipe learned...).
local CT = FuryCT
local U = CT.Util
local Scan = {}
CT.Scan = Scan

local SCAN_DELAY_MS = 3000
local RESEARCH_CRAFTS = {
    CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING,
}
-- Events that change the Wallet & CP tab (the third is filtered to the backpack).
local WALLET_EVENTS = { "EVENT_MONEY_UPDATE", "EVENT_CURRENCY_UPDATE", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
                        "EVENT_CHAMPION_PURCHASE_RESULT", "EVENT_UNSPENT_CHAMPION_POINTS_CHANGED" }

-- Event names, looked up at start so a name a game version doesn't have is skipped, not an error.
local RESCAN_EVENTS = {
    "EVENT_SKILL_RANK_UPDATE", "EVENT_SKILL_LINE_ADDED", "EVENT_SKILL_POINTS_CHANGED",
    "EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED", "EVENT_SMITHING_TRAIT_RESEARCH_STARTED",
    "EVENT_SMITHING_TRAIT_RESEARCH_CANCELED", "EVENT_SMITHING_TRAIT_RESEARCH_TIMES_UPDATED",
    "EVENT_RECIPE_LEARNED", "EVENT_MULTIPLE_RECIPES_LEARNED", "EVENT_RIDING_SKILL_IMPROVEMENT", "EVENT_COLLECTIBLE_UPDATED",
}

function Scan.CurrentName()
    return U.Plain(GetUnitName("player"))
end

function Scan:Start()
    -- Wait a few seconds after login: the game builds its skill data at the same moment.
    self:Queue()
    for i, eventName in ipairs(RESCAN_EVENTS) do
        local event = _G[eventName]
        if event then EVENT_MANAGER:RegisterForEvent(CT.name .. "Rescan" .. i, event, function() self:Queue() end) end
    end
    EVENT_MANAGER:RegisterForEvent(CT.name .. "Companion", EVENT_ACTIVE_COMPANION_STATE_CHANGED, Scan.OnCompanionStateChanged)
    for i, eventName in ipairs(WALLET_EVENTS) do
        local event = _G[eventName]
        if event then EVENT_MANAGER:RegisterForEvent(CT.name .. "Wallet" .. i, event, Scan.QueueWallet) end
    end
    EVENT_MANAGER:AddFilterForEvent(CT.name .. "Wallet3", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    CT.Daily:Start()
    -- Time played only moves while you play: catch it on the way out (logout, /reloadui).
    EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_PLAYER_DEACTIVATED, function()
        CT.Roster:UpdatePlayed(Scan.CurrentName(), GetSecondsPlayed())
    end)
end

-- Many events can arrive together (learning a stack of recipes); read once when they settle.
-- Money and backpack change often: update the wallet at most every few seconds.
function Scan.QueueWallet()
    local key = CT.name .. "WalletUpdate"
    EVENT_MANAGER:UnregisterForUpdate(key)
    EVENT_MANAGER:RegisterForUpdate(key, 3000, function()
        EVENT_MANAGER:UnregisterForUpdate(key)
        local c = CT.sv.characters[Scan.CurrentName()]
        if c then
            Scan.ReadWallet(c)
            CT.Window:RefreshIfShown()
        end
    end)
end

function Scan:Queue()
    local key = CT.name .. "Scan"
    EVENT_MANAGER:UnregisterForUpdate(key)
    EVENT_MANAGER:RegisterForUpdate(key, SCAN_DELAY_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(key)
        self:Run()
    end)
end

-- Skill lines on the board: current rank, 0 if not discovered.
local function ReadLines()
    local lines = {}
    for skillType = 1, SKILL_TYPE_MAX_VALUE do
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local name, rank, available, skillLineId, _, _, _, discovered = GetSkillLineInfo(skillType, lineIndex)
            name = CT.SKILL_LINE_IDS[skillLineId] or U.Plain(name)
            if CT.LINE_BY_NAME[name] then
                lines[name] = (available or discovered) and rank or 0
            end
        end
    end
    return lines
end

-- Points spent on every skill plus the ones not spent yet. Asks the game's own skill data (what the
-- Skills window uses for respec), so morphs, passive ranks, free auto-granted skills and subclass
-- lines are all counted the way the game counts them.
local function ReadSkillPoints()
    local spent = 0
    -- These loops hand back (index, data), like ipairs.
    for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, skillLineData in skillTypeData:SkillLineIterator() do
            for _, skillData in skillLineData:SkillIterator() do
                spent = spent + skillData:GetPointAllocator():GetNumPointsAllocated()
            end
        end
    end
    local unspent = GetAvailableSkillPoints()
    if spent == 0 then return nil, unspent end   -- skill data not ready yet: keep the last good number
    return spent + unspent, unspent
end

-- Traits per craft: how many known, the ones still missing (per item), research slots, and what is
-- being researched now with the time it finishes (a timestamp, so it can be counted down on any character).
local function ReadResearch()
    local known, total, crafts = 0, 0, {}
    local now = GetTimeStamp()
    for _, craft in ipairs(RESEARCH_CRAFTS) do
        local entry = { craft = craft, known = 0, total = 0, slots = GetMaxSimultaneousSmithingResearch(craft),
                        missing = {}, timers = {} }
        for lineIndex = 1, GetNumSmithingResearchLines(craft) do
            local itemName, _, numTraits = GetSmithingResearchLineInfo(craft, lineIndex)
            itemName = U.Plain(itemName)
            local missing = {}
            for traitIndex = 1, numTraits do
                local traitType, _, isKnown = GetSmithingResearchLineTraitInfo(craft, lineIndex, traitIndex)
                local traitName = U.Plain(GetString("SI_ITEMTRAITTYPE", traitType))
                entry.total = entry.total + 1
                if isKnown then
                    entry.known = entry.known + 1
                else
                    missing[#missing + 1] = traitName
                    local _, remaining = GetSmithingResearchLineTraitTimes(craft, lineIndex, traitIndex)
                    if remaining and remaining > 0 then
                        entry.timers[#entry.timers + 1] = { item = itemName, trait = traitName, endsAt = now + remaining }
                    end
                end
            end
            if #missing > 0 then entry.missing[#entry.missing + 1] = { item = itemName, traits = missing, of = numTraits } end
        end
        known, total = known + entry.known, total + entry.total
        crafts[#crafts + 1] = entry
    end
    return known, total, crafts
end

-- Provisioning recipes and furnishing plans live in the same recipe lists;
-- the crafting station each one needs tells them apart.
local function ReadRecipes()
    local recipes, recipesTotal, plans, plansTotal = 0, 0, 0, 0
    for listIndex = 1, GetNumRecipeLists() do
        local _, numRecipes = GetRecipeListInfo(listIndex)
        for recipeIndex = 1, numRecipes do
            local known, _, _, _, _, _, station = GetRecipeInfo(listIndex, recipeIndex)
            if station == CRAFTING_TYPE_PROVISIONING then
                recipesTotal = recipesTotal + 1
                if known then recipes = recipes + 1 end
            else
                plansTotal = plansTotal + 1
                if known then plans = plans + 1 end
            end
        end
    end
    return recipes, recipesTotal, plans, plansTotal
end

-- Scribing is learned like recipes: a set number of grimoires and scripts per character.
-- Counted the way Character Knowledge counts it (79 when everything is known): grimoires
-- plus scripts. Many scripts fit several grimoires, so each script is counted once.
local function ReadScribing()
    local seen = {}
    local grimoires, grimoiresTotal, scripts, scriptsTotal = 0, 0, 0, 0
    for index = 1, GetNumCraftedAbilities() do
        local craftedAbilityId = GetCraftedAbilityIdAtIndex(index)
        grimoiresTotal = grimoiresTotal + 1
        if IsCraftedAbilityUnlocked(craftedAbilityId) then grimoires = grimoires + 1 end
        for slot = 1, 3 do   -- primary (focus), secondary (signature), tertiary (affix)
            for scriptIndex = 1, GetNumScriptsInSlotForCraftedAbility(craftedAbilityId, slot) do
                local scriptId = GetScriptIdAtSlotIndexForCraftedAbility(craftedAbilityId, slot, scriptIndex)
                if scriptId and scriptId ~= 0 and not seen[scriptId] then
                    seen[scriptId] = true
                    scriptsTotal = scriptsTotal + 1
                    if IsCraftedAbilityScriptUnlocked(scriptId) then scripts = scripts + 1 end
                end
            end
        end
    end
    return grimoires, grimoiresTotal, scripts, scriptsTotal
end

-- Motif styles known in full. The game's own count: it is known to get one or two styles wrong
-- (Mercenary, for one), so it can differ slightly from crafting addons that track chapters by hand.
local function ReadMotifs()
    local known, total = 0, 0
    for index = 1, GetNumValidItemStyles() do
        local styleId = GetValidItemStyleId(index)
        if styleId and styleId > 0 then
            total = total + 1
            if IsSmithingStyleKnown(styleId) then known = known + 1 end
        end
    end
    return known, total
end

-- Account-wide collections, read from whichever character is logged in:
-- the item set collection ("sticker book", set pieces unlocked) and outfit styles.
local function ReadAccountCollections()
    local pieces, piecesTotal = 0, 0
    local setId = GetNextItemSetCollectionId()
    while setId do
        piecesTotal = piecesTotal + GetNumItemSetCollectionPieces(setId)
        pieces = pieces + GetNumItemSetCollectionSlotsUnlocked(setId)
        setId = GetNextItemSetCollectionId(setId)
    end
    local styles, stylesTotal = 0, 0
    local categoryType = COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE
    for index = 1, GetTotalCollectiblesByCategoryType(categoryType) do
        stylesTotal = stylesTotal + 1
        if IsCollectibleUnlocked(GetCollectibleIdFromType(categoryType, index)) then styles = styles + 1 end
    end
    local names = {}
    for index = 1, GetNumCharacters() do names[#names + 1] = U.Plain((GetCharacterInfo(index))) end
    CT.sv.account = { setPieces = pieces, setPiecesTotal = piecesTotal, outfitStyles = styles,
                      outfitStylesTotal = stylesTotal, championPoints = GetPlayerChampionPointsEarned(),
                      achievementTotal = GetTotalAchievementPoints(), characterNames = names, lastScan = GetTimeStamp() }
end

-- "Sharp-as-Night" -> "Sharp", "Azandar al-Cybiades" -> "Azandar": short names for the board.
local function ShortCompanionName(name)
    return name:match("^[^%s%-]+") or name
end

-- Companions: the collectible is account-wide, but each character has to finish the companion's
-- intro quest before it can summon them. So a companion counts for this character when the intro
-- quest is in its completed quests, or when you have summoned that companion on it (which also
-- covers characters that skip the quest after you have unlocked a companion on three others).
local INTRO_QUESTS = {
    ["competition and contracts"] = "Bastian", ["shattered and scattered"] = "Mirri",
    ["tower full of trouble"] = "Ember", ["tournament of the heart"] = "Isobel",
    ["the double edge"] = "Sharp", ["the fateweaver key"] = "Azandar",
    ["the garland ring"] = "Tanlorin", ["a moonlit shadow"] = "Zerith", ["a moonlight shadow"] = "Zerith",
}

local function CompletedIntroQuests()
    local done = {}
    local questId = GetNextCompletedQuestId()
    while questId do
        local companion = CT.INTRO_QUEST_IDS[questId] or INTRO_QUESTS[zo_strlower(U.Plain(GetCompletedQuestInfo(questId)))]
        if companion then done[companion] = true end
        questId = GetNextCompletedQuestId(questId)
    end
    return done
end

local function ReadCompanions()
    local unlocked, total = {}, 0
    local done = CompletedIntroQuests()
    local seen = (CT.sv.companionSeen or {})[Scan.CurrentName()] or {}
    local categoryType = COLLECTIBLE_CATEGORY_TYPE_COMPANION
    for index = 1, GetTotalCollectiblesByCategoryType(categoryType) do
        local collectibleId = GetCollectibleIdFromType(categoryType, index)
        local name = ShortCompanionName(U.Plain(GetCollectibleName(collectibleId)))
        total = total + 1
        if IsCollectibleUnlocked(collectibleId) and (done[name] or seen[name]) then
            unlocked[#unlocked + 1] = name
        end
    end
    table.sort(unlocked)
    return unlocked, total
end

-- Money, bag space and Champion Points spent, for the Wallet & CP tab. Cheap, so it also runs
-- (throttled) whenever money or the backpack changes.
local function Currency(currency, location)
    return GetCurrencyAmount(currency, location or CURRENCY_LOCATION_CHARACTER) or 0
end

function Scan.ReadWallet(c)
    c.gold = GetCurrentMoney()
    c.telvar = Currency(CURT_TELVAR_STONES)
    c.ap = Currency(CURT_ALLIANCE_POINTS)
    c.vouchers = Currency(CURT_WRIT_VOUCHERS)
    c.bagUsed, c.bagSize = GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)
    c.cp = {}
    for index = 1, GetNumChampionDisciplines() do
        local id = GetChampionDisciplineId(index)
        c.cp[index] = { name = U.Plain(GetChampionDisciplineName(id)), spent = GetNumSpentChampionPoints(id),
                        unspent = GetNumUnspentChampionPoints(id) }
    end
    local account = CT.sv.account or {}
    CT.sv.account = account
    account.bankGold = GetBankedCurrencyAmount(CURT_MONEY)
    account.bankTelvar = GetBankedCurrencyAmount(CURT_TELVAR_STONES)
    account.bankAP = GetBankedCurrencyAmount(CURT_ALLIANCE_POINTS)
    account.bankVouchers = GetBankedCurrencyAmount(CURT_WRIT_VOUCHERS)
    account.transmutes = Currency(CURT_CHAOTIC_CREATIA, CURRENCY_LOCATION_ACCOUNT)
    account.bankUsed = GetNumBagUsedSlots(BAG_BANK) + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    account.bankSize = GetBagSize(BAG_BANK) + GetBagSize(BAG_SUBSCRIBER_BANK)
end

-- /fct ids: prints the language-neutral IDs of every tracked skill line and companion intro quest
-- this character has, ready to paste into Data/Lines.lua. Run it on an English client.
function Scan:PrintIds()
    local lineIds, questIds = {}, {}
    for skillType = 1, SKILL_TYPE_MAX_VALUE do
        for lineIndex = 1, GetNumSkillLines(skillType) do
            local name, _, _, skillLineId = GetSkillLineInfo(skillType, lineIndex)
            name = U.Plain(name)
            if CT.LINE_BY_NAME[name] then lineIds[#lineIds + 1] = string.format("[%d] = \"%s\"", skillLineId, name) end
        end
    end
    local questId = GetNextCompletedQuestId()
    while questId do
        local companion = INTRO_QUESTS[zo_strlower(U.Plain(GetCompletedQuestInfo(questId)))]
        if companion then questIds[#questIds + 1] = string.format("[%d] = \"%s\"", questId, companion) end
        questId = GetNextCompletedQuestId(questId)
    end
    table.sort(lineIds); table.sort(questIds)
    U.Print("Skill line IDs (%d): %s", #lineIds, table.concat(lineIds, ", "))
    U.Print("Companion quest IDs (%d): %s", #questIds, table.concat(questIds, ", "))
    CT.sv.ids = { lines = lineIds, quests = questIds }   -- also saved, so they can be read from the file
end

-- Summoning a companion proves this character has it.
function Scan.OnCompanionStateChanged()
    if not HasActiveCompanion() then return end
    local collectibleId = GetCompanionCollectibleId(GetActiveCompanionDefId())
    if not collectibleId or collectibleId == 0 then return end
    local name = ShortCompanionName(U.Plain(GetCollectibleName(collectibleId)))
    CT.sv.companionSeen = CT.sv.companionSeen or {}
    local character = Scan.CurrentName()
    CT.sv.companionSeen[character] = CT.sv.companionSeen[character] or {}
    if not CT.sv.companionSeen[character][name] then
        CT.sv.companionSeen[character][name] = true
        Scan:Queue()
    end
end

function Scan:Run()
    local c = { source = "live", lastScan = GetTimeStamp() }
    c.id = GetCurrentCharacterId()
    c.class = U.Plain(GetUnitClass("player"))
    c.classId = GetUnitClassId("player")
    c.race = U.Plain(GetUnitRace("player"))
    c.alliance = U.Plain(GetAllianceName(GetUnitAlliance("player")))
    c.level = GetUnitLevel("player")
    c.playedHours = zo_round(GetSecondsPlayed() / 3600)
    c.lines = ReadLines()
    c.skillPoints, c.unspent = ReadSkillPoints()
    c.research, c.researchTotal, c.researchCrafts = ReadResearch()
    c.recipes, c.recipesTotal, c.furnishings, c.furnishingsTotal = ReadRecipes()
    c.companions, c.companionsTotal = ReadCompanions()
    c.motifs, c.motifsTotal = ReadMotifs()
    c.achievementPoints = GetEarnedAchievementPoints()
    ReadAccountCollections()
    c.grimoires, c.grimoiresTotal, c.scriptsOnly, c.scriptsOnlyTotal = ReadScribing()
    c.scripts, c.scriptsTotal = c.grimoires + c.scriptsOnly, c.grimoiresTotal + c.scriptsOnlyTotal
    local carry, carryMax, stamina, staminaMax, speed, speedMax = GetRidingStats()
    c.riding, c.ridingMax = carry + stamina + speed, carryMax + staminaMax + speedMax
    c.ridingReadyAt = CT.Daily.RidingReadyAt(c.riding, c.ridingMax)
    local previous = CT.sv.characters[Scan.CurrentName()]
    c.writs = CT.Daily.ReadWrits(previous and previous.writs)
    Scan.ReadWallet(c)

    c.craftMaxed = 0
    for _, group in ipairs(CT.GROUPS) do
        if group.id == "crafting" then c.craftMaxed = CT.Roster:MaxedInGroup(c, group) end
    end

    CT.Roster:Store(Scan.CurrentName(), c)
end
