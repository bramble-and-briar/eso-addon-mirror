CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

CompanionRoster.name = "CompanionRoster"
CompanionRoster.savedVariablesVersion = 1
CompanionRoster.Data = {}

-- Keep this in sync with ## Version in CompanionRoster.txt on every bump -
-- there's no runtime API that reads the manifest's free-text Version
-- string back (GetAddOnManager():GetAddOnVersion() returns the separate
-- numeric ## AddOnVersion tag instead, meant for dependency checks, not
-- display), so this has to be maintained by hand.
CompanionRoster.version = "2.2.1"

local savedVars = nil

local function GetCharacterKey()
    return GetUnitName("player")
end

local function GetOrCreateCharacterEntry(characterKey)
    if savedVars.characters[characterKey] == nil then
        savedVars.characters[characterKey] = { companions = {}, introQuestsDone = {} }
    end
    if savedVars.characters[characterKey].introQuestsDone == nil then
        savedVars.characters[characterKey].introQuestsDone = {}
    end
    return savedVars.characters[characterKey]
end

-- companionId is a small integer (currently 1 through the low teens, with
-- gaps) valid to query directly for any companion regardless of summon
-- state. Set comfortably above the current range so new companions are
-- picked up automatically without a code change.
local MAX_COMPANION_DEF_ID = 30

-- Public read API. Kept narrow and free of any UI concerns so this file
-- could be lifted into a standalone embeddable library later without
-- reworking its interface.

-- All real companions, discovered live rather than hardcoded, in display
-- (alphabetical) order. Each entry: { id = companionId, collectibleId =
-- <the companion's own collectible id>, name = <display name> }.
function CompanionRoster.Data.GetAllCompanions()
    local companions = {}
    for companionId = 1, MAX_COMPANION_DEF_ID do
        local collectibleId = GetCompanionCollectibleId(companionId)
        if collectibleId ~= nil and collectibleId > 0 then
            table.insert(companions, {
                id = companionId,
                collectibleId = collectibleId,
                name = zo_strformat("<<1>>", GetCompanionName(companionId)),
            })
        end
    end
    table.sort(companions, function(a, b) return a.name < b.name end)
    return companions
end

-- The skill types shown grouped in the Level tooltip - not Racial (the
-- reasoning was "I would summon them for that info") and not every
-- SKILL_TYPE_* that exists, just the ones companions actually have.
local COMPANION_SKILL_TYPES = { SKILL_TYPE_CLASS, SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_GUILD }

-- Skill line names/ranks for whichever companion is currently summoned,
-- grouped by type. Like rapport, this is only readable while that
-- companion is actually summoned - returns nil if companion skill data
-- hasn't initialized yet (e.g. right at summon).
local function GetActiveCompanionSkillLines()
    if not AreCompanionSkillsInitialized() then
        return nil
    end

    local skillTypeGroups = {}
    for _, skillType in ipairs(COMPANION_SKILL_TYPES) do
        local lines = {}
        for skillLineIndex = 1, GetNumCompanionSkillLines(skillType) do
            local skillLineId = GetCompanionSkillLineId(skillType, skillLineIndex)
            local currentRank = GetCompanionSkillLineDynamicInfo(skillLineId)
            -- At max rank, currentXP sits pinned equal to nextRankXP (no
            -- further rank to roll over into) - confirmed live via debug
            -- print against a companion with a genuinely maxed Guild line
            -- (rank 10: lastRankXP=800, nextRankXP=900, currentXP=900).
            -- nextRankXP == 0 was the original (wrong) assumption - it
            -- never actually hits 0 for companion skill lines.
            local lastRankXP, nextRankXP, currentXP = GetCompanionSkillLineXPInfo(skillLineId)
            table.insert(lines, {
                name = zo_strformat("<<1>>", GetCompanionSkillLineNameById(skillLineId)),
                rank = currentRank,
                isMaxed = (currentXP >= nextRankXP),
                lastRankXP = lastRankXP,
                nextRankXP = nextRankXP,
                currentXP = currentXP,
            })
        end
        if #lines > 0 then
            table.insert(skillTypeGroups, { typeName = GetString("SI_SKILLTYPE", skillType), lines = lines })
        end
    end
    return skillTypeGroups
end

local function RecordActiveCompanion()
    if not HasActiveCompanion() then
        return
    end

    local companionId = GetActiveCompanionDefId()
    if companionId == nil or companionId == 0 then
        return
    end

    local rapportLevel = GetActiveCompanionRapportLevel()
    local level = GetActiveCompanionLevelInfo()
    local passivePerkId = GetCompanionPassivePerkAbilityId(companionId)

    local character = GetOrCreateCharacterEntry(GetCharacterKey())
    -- Start from the existing entry (not a fresh table) so a capture that
    -- catches companion skills before they've initialized (see
    -- GetActiveCompanionSkillLines) doesn't wipe out a previously-recorded
    -- skillLines with nil.
    local entry = character.companions[companionId] or {}

    entry.name = zo_strformat("<<1>>", GetCompanionName(companionId))
    entry.level = level
    entry.rapportValue = GetActiveCompanionRapport()
    entry.rapportMax = GetMaximumRapport()
    entry.rapportLevel = rapportLevel
    entry.rapportLevelText = GetActiveCompanionRapportLevelDescription(rapportLevel)
    entry.passivePerkName = zo_strformat("<<1>>", GetAbilityName(passivePerkId))
    entry.passivePerkDescription = GetAbilityDescription(passivePerkId)
    entry.lastUpdated = GetTimeStamp()

    local skillLines = GetActiveCompanionSkillLines()
    if skillLines then
        entry.skillLines = skillLines
    end

    character.companions[companionId] = entry
end

-- Live-queryable for any companion without needing it summoned, but only
-- reflects the character currently logged in. Empty quest name means not
-- completed by this character.
local function IsIntroQuestCompleteForActiveCharacter(companionId)
    local introQuestId = GetCompanionIntroQuestId(companionId)
    if introQuestId == nil or introQuestId == 0 then
        return false
    end
    local questName = GetCompletedQuestInfo(introQuestId)
    return questName ~= nil and questName ~= ""
end

-- Records, for the currently active character, whether each companion's
-- recruitment quest is done - not tied to any particular companion being
-- summoned, unlike rapport/level/perk, so this runs once per login/reload
-- for every known companion rather than being event-driven per companion.
local function RecordIntroQuestCompletion()
    local character = GetOrCreateCharacterEntry(GetCharacterKey())
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        character.introQuestsDone[companion.id] = IsIntroQuestCompleteForActiveCharacter(companion.id)
    end
end

local function OnPlayerActivated()
    RecordActiveCompanion()
    RecordIntroQuestCompletion()
end

local function OnCompanionActivated()
    RecordActiveCompanion()
end

local function OnCompanionRapportUpdate()
    RecordActiveCompanion()
end

local function OnCompanionExperienceGain()
    RecordActiveCompanion()
end

-- Companion skills initialize on their own timeline after summon (the
-- client's own source notes they're built and torn down as the active
-- companion changes) - re-capture here rather than waiting for a rapport
-- or XP event that might not happen this session.
local function OnCompanionSkillsFullUpdate()
    RecordActiveCompanion()
end

function CompanionRoster.Data.GetCharacterNames()
    local names = {}
    for characterKey in pairs(savedVars.characters) do
        table.insert(names, characterKey)
    end
    table.sort(names)
    return names
end

function CompanionRoster.Data.GetCurrentCharacterName()
    return GetCharacterKey()
end

-- Window position is a UI preference, not game data, so it's account-wide
-- (not per-character) - independent of savedVars.characters.
function CompanionRoster.Data.SaveWindowPosition(point, relativePoint, offsetX, offsetY)
    savedVars.windowPosition = { point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
end

function CompanionRoster.Data.GetWindowPosition()
    return savedVars.windowPosition
end

-- The chat command that toggles the window - also a UI preference, so
-- account-wide like the window position above. Changing it is applied live
-- (LibSlashCommander's Command:RemoveAlias/AddAlias write straight into the
-- real SLASH_COMMANDS table), not just recorded for next login.
function CompanionRoster.Data.GetSlashCommand()
    return savedVars.slashCommand
end

function CompanionRoster.Data.SetSlashCommand(command)
    savedVars.slashCommand = command
end

-- Also a UI preference, account-wide like the two above. Off by default -
-- specifically for entering combat (EVENT_PLAYER_COMBAT_STATE), not
-- movement - see CompanionRoster_UI.lua for why movement isn't supported.
function CompanionRoster.Data.GetCloseOnCombat()
    return savedVars.closeOnCombat
end

function CompanionRoster.Data.SetCloseOnCombat(enabled)
    savedVars.closeOnCombat = enabled
end

-- Another account-wide UI preference. On by default - it only has an effect
-- once the player has tagged a companion with a Role.
function CompanionRoster.Data.GetShowRoleOnCollections()
    return savedVars.showRoleOnCollections
end

function CompanionRoster.Data.SetShowRoleOnCollections(enabled)
    savedVars.showRoleOnCollections = enabled
end

function CompanionRoster.Data.GetShowRapportOnCollections()
    return savedVars.showRapportOnCollections
end

function CompanionRoster.Data.SetShowRapportOnCollections(enabled)
    savedVars.showRapportOnCollections = enabled
end

function CompanionRoster.Data.GetCompanionsForCharacter(characterKey)
    local character = savedVars.characters[characterKey]
    if character == nil then
        return {}
    end
    return character.companions
end

-- A companion's passive perk doesn't vary by character, unlike rapport and
-- level - so if the currently selected character hasn't recorded it yet,
-- fall back to any character that has.
function CompanionRoster.Data.GetPassivePerkInfo(companionId)
    for _, character in pairs(savedVars.characters) do
        local info = character.companions[companionId]
        if info and info.passivePerkName then
            return info.passivePerkName, info.passivePerkDescription
        end
    end
    return nil, nil
end

-- Companion skill progress is account-wide, like the passive perk above -
-- fall back to any character that has recorded it for this companion.
-- Returns nil if no character has recorded it yet. Shape: an ordered list
-- of { typeName = "Class", lines = { { name = "Ardent Warrior", rank = 20 }, ... } }.
function CompanionRoster.Data.GetSkillLinesForCompanion(companionId)
    for _, character in pairs(savedVars.characters) do
        local info = character.companions[companionId]
        if info and info.skillLines then
            return info.skillLines
        end
    end
    return nil
end

-- True only if every recorded Guild-type skill line is at max rank - a
-- companion's Guild line can only progress through completing quests
-- (not grindable the way Class/Weapon/Armor are), so reaching max is a
-- genuine milestone worth calling out. False if no Guild skill line has
-- been recorded yet (companion never summoned), not just if it's low rank.
function CompanionRoster.Data.IsGuildSkillLineMaxed(skillLines)
    if skillLines == nil then
        return false
    end

    local guildTypeName = GetString("SI_SKILLTYPE", SKILL_TYPE_GUILD)
    for _, group in ipairs(skillLines) do
        if group.typeName == guildTypeName then
            for _, line in ipairs(group.lines) do
                if not line.isMaxed then
                    return false
                end
            end
            return #group.lines > 0
        end
    end
    return false
end

-- Summary of every one of a companion's Guild-type skill lines (name,
-- rank, and progress toward the next rank) - a companion can hold rank in
-- more than one guild at once (Fighters Guild/Mages Guild/Undaunted all
-- independently), confirmed live, so this lists all of them, not just the
-- first found. General context for deciding who to bring out, not tied to
-- whatever term a rapport-tips search matched. Returns nil if no Guild
-- skill line has been recorded for this companion yet (never summoned).
function CompanionRoster.Data.GetGuildSkillLineSummary(companionId)
    local skillLines = CompanionRoster.Data.GetSkillLinesForCompanion(companionId)
    if skillLines == nil then
        return nil
    end

    local guildTypeName = GetString("SI_SKILLTYPE", SKILL_TYPE_GUILD)
    for _, group in ipairs(skillLines) do
        if group.typeName == guildTypeName then
            local summaryLines = {}
            for _, line in ipairs(group.lines) do
                if line.isMaxed then
                    table.insert(summaryLines, string.format("%s Rank %d (Maxed)", line.name, line.rank))
                elseif line.currentXP and line.lastRankXP and line.nextRankXP then
                    local xpIntoRank = line.currentXP - line.lastRankXP
                    table.insert(summaryLines, string.format("%s Rank %d, %d/%d XP to next", line.name, line.rank, xpIntoRank, line.nextRankXP))
                else
                    -- Recorded before this addon tracked XP progress - falls
                    -- back to just the rank until this companion is
                    -- resummoned and recaptured with the newer fields.
                    table.insert(summaryLines, string.format("%s Rank %d", line.name, line.rank))
                end
            end
            return #summaryLines > 0 and table.concat(summaryLines, "\n") or nil
        end
    end
    return nil
end

-- The player's own tag for how they've built a companion (Tank/Healer/DPS)
-- - there's no API to derive this from gear or slotted skills, it's purely
-- a manual label. Stored account-wide (independent of savedVars.characters)
-- since a companion's actual build already is - see GetSkillLinesForCompanion
-- above. Value is nil (no role set) or one of LFG_ROLE_TANK/LFG_ROLE_HEAL/
-- LFG_ROLE_DPS, the same engine constants the game's own Group Finder uses.
function CompanionRoster.Data.GetCompanionRole(companionId)
    return savedVars.companionRoles[companionId]
end

function CompanionRoster.Data.SetCompanionRole(companionId, role)
    savedVars.companionRoles[companionId] = role
end

-- Companion -> Keepsake collectible id. The Keepsake (Collections >
-- Upgrade > Companion Keepsakes) makes that companion's passive perk
-- always active, even when not summoned, once its meta-achievement is
-- done. No API derives this id from a companionId, so it's hardcoded -
-- found via chat-linking each one in-game (|H1:collectible:<id>|h|h).
local KEEPSAKE_COLLECTIBLE_IDS = {
    ["Azandar"] = 11453,
    ["Bastian Hallix"] = 9457,
    ["Ember"] = 10436,
    ["Isobel Veloise"] = 10437,
    ["Mirri Elendis"] = 9458,
    ["Sharp-as-Night"] = 11452,
    ["Tanlorin"] = 12227,
    ["Zerith-var"] = 12228,
}

-- Account-wide, so this doesn't depend on which character is selected.
function CompanionRoster.Data.IsKeepsakeUnlocked(companionName)
    local collectibleId = KEEPSAKE_COLLECTIBLE_IDS[companionName]
    if collectibleId == nil then
        return false
    end
    return IsCollectibleUnlocked(collectibleId)
end

-- Whether the account has this companion's own collectible at all
-- (account-wide - the same "Collected" flag the Collections screen shows).
-- Note this is NOT the same as being able to summon them on any particular
-- character - see CanSummonCompanion below for that.
function CompanionRoster.Data.IsCompanionOwned(companionId)
    local collectibleId = GetCompanionCollectibleId(companionId)
    if collectibleId == nil or collectibleId == 0 then
        return false
    end
    return IsCollectibleUnlocked(collectibleId)
end

-- Owned account-wide AND this character has completed the recruitment
-- quest - the Collections screen can show a companion as "Collected"
-- while still blocking summon on a character who hasn't personally met
-- them, so ownership alone isn't enough. Returns true/false if known, or
-- nil if this character's quest completion was never recorded.
function CompanionRoster.Data.CanSummonCompanion(characterKey, companionId)
    if not CompanionRoster.Data.IsCompanionOwned(companionId) then
        return false
    end

    local character = savedVars.characters[characterKey]
    if character == nil or character.introQuestsDone == nil then
        return nil
    end
    return character.introQuestsDone[companionId]
end

local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= CompanionRoster.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("CompanionRoster_Data", EVENT_ADD_ON_LOADED)

    -- GetWorldName() as the namespace splits saved data by server (EU/NA/PTS)
    -- rather than mixing it - matters because data here is keyed by
    -- character name, not character id, and the same @account can play on
    -- more than one server where two different characters could share a name.
    local defaults = { characters = {}, companionRoles = {}, slashCommand = "/fcr", closeOnCombat = false, showRoleOnCollections = true, showRapportOnCollections = true }
    savedVars = ZO_SavedVars:NewAccountWide("CompanionRoster_SavedVariables", CompanionRoster.savedVariablesVersion, GetWorldName(), defaults)

    EVENT_MANAGER:RegisterForEvent("CompanionRoster_Data", EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_Data", EVENT_COMPANION_RAPPORT_UPDATE, OnCompanionRapportUpdate)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_Data", EVENT_COMPANION_EXPERIENCE_GAIN, OnCompanionExperienceGain)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_Data", EVENT_COMPANION_SKILLS_FULL_UPDATE, OnCompanionSkillsFullUpdate)
    EVENT_MANAGER:RegisterForEvent("CompanionRoster_Data", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent("CompanionRoster_Data", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
