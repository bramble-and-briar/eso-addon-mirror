CompanionRoster = CompanionRoster or {}
local CompanionRoster = CompanionRoster -- local reference, faster than repeated _G lookups

CompanionRoster.name = "CompanionRoster"
-- The addon's title, shown in the window, the chat prefix and the settings
-- panel. Not translated on purpose, like the title in the manifest.
CompanionRoster.title = "Feliks' Companion Roster"
CompanionRoster.savedVariablesVersion = 1
CompanionRoster.Data = {}

-- Keep this in sync with ## Version in CompanionRoster.txt on every bump -
-- there's no runtime API that reads the manifest's free-text Version
-- string back (GetAddOnManager():GetAddOnVersion() returns the separate
-- numeric ## AddOnVersion tag instead, meant for dependency checks, not
-- display), so this has to be maintained by hand.
CompanionRoster.version = "2.4.0"

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

-- The list below only changes if the game's companion data does, so it's
-- built once and reused. An empty result isn't kept (the game data may not be
-- ready yet), and both caches are dropped once at the first
-- EVENT_PLAYER_ACTIVATED in case the list was built before it was.
local companionListCache = nil
local companionIdByCollectibleIdCache = nil

-- All real companions, discovered live rather than hardcoded, in display
-- (alphabetical) order. Each entry: { id = companionId, collectibleId =
-- <the companion's own collectible id>, name = <display name> }. The returned
-- table is shared - treat it as read-only.
function CompanionRoster.Data.GetAllCompanions()
    if companionListCache then
        return companionListCache
    end

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

    if #companions > 0 then
        companionListCache = companions
    end
    return companions
end

-- The display name for a companionId, or nil if the game has no such companion.
function CompanionRoster.Data.GetCompanionNameById(companionId)
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        if companion.id == companionId then
            return companion.name
        end
    end
    return nil
end

-- The companionId whose own collectible is `collectibleId`, or nil if it isn't
-- a companion's. Used by the Collections screen hook, which asks once per tile
-- layout.
function CompanionRoster.Data.GetCompanionIdForCollectible(collectibleId)
    if companionIdByCollectibleIdCache == nil then
        local map = {}
        for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
            map[companion.collectibleId] = companion.id
        end
        if next(map) == nil then
            return nil
        end
        companionIdByCollectibleIdCache = map
    end
    return companionIdByCollectibleIdCache[collectibleId]
end

-- The skill types shown grouped in the Level tooltip - not Racial (the
-- reasoning was "I would summon them for that info") and not every
-- SKILL_TYPE_* that exists, just the ones companions actually have.
local COMPANION_SKILL_TYPES = { SKILL_TYPE_CLASS, SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_GUILD }

-- A recorded skill type group's SKILL_TYPE_*. Groups recorded by older
-- versions only have the display text (typeName), so those are matched against
-- the client's current names for the types we record.
local function GetSkillGroupType(group)
    if group.skillType ~= nil then
        return group.skillType
    end
    for _, skillType in ipairs(COMPANION_SKILL_TYPES) do
        if GetString("SI_SKILLTYPE", skillType) == group.typeName then
            return skillType
        end
    end
    return nil
end

function CompanionRoster.Data.IsGuildSkillGroup(group)
    return GetSkillGroupType(group) == SKILL_TYPE_GUILD
end

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
        local seenIds, seenNames = {}, {}
        local lineCount = GetNumCompanionSkillLines(skillType)
        for skillLineIndex = 1, lineCount do
            local skillLineId = GetCompanionSkillLineId(skillType, skillLineIndex)
            local lineName = zo_strformat("<<1>>", GetCompanionSkillLineNameById(skillLineId))

            -- While a rank is changing the game's list can repeat a line: seen
            -- live with a Restoration Staff rank-up mid-fight, where the same
            -- skillLineId (185) came back as an extra last entry (index 7 of
            -- 7). So each line is only recorded once per group; the name check
            -- is just a second guard.
            if not (seenIds[skillLineId] or seenNames[lineName]) then
                seenIds[skillLineId] = true
                seenNames[lineName] = true

                local currentRank = GetCompanionSkillLineDynamicInfo(skillLineId)
                -- At max rank, currentXP sits pinned equal to nextRankXP (no
                -- further rank to roll over into) - confirmed live via debug
                -- print against a companion with a genuinely maxed Guild line
                -- (rank 10: lastRankXP=800, nextRankXP=900, currentXP=900).
                -- nextRankXP == 0 was the original (wrong) assumption - it
                -- never actually hits 0 for companion skill lines.
                local lastRankXP, nextRankXP, currentXP = GetCompanionSkillLineXPInfo(skillLineId)
                table.insert(lines, {
                    skillLineId = skillLineId,
                    name = lineName,
                    rank = currentRank,
                    isMaxed = (currentXP >= nextRankXP),
                    lastRankXP = lastRankXP,
                    nextRankXP = nextRankXP,
                    currentXP = currentXP,
                })
            end
        end
        if #lines > 0 then
            -- skillType (a number) is what code compares; typeName is the
            -- display text in the client's language at the time.
            table.insert(skillTypeGroups, { skillType = skillType, typeName = GetString("SI_SKILLTYPE", skillType), lines = lines })
        end
    end
    return skillTypeGroups
end

-- Lets the roster window redraw if it's open (see CompanionRoster_UI.lua).
local function NotifyDataRecorded()
    if CompanionRoster.OnDataRecorded then
        CompanionRoster.OnDataRecorded()
    end
end

-- The companion currently summoned, or nil if there isn't one.
local function GetActiveCompanionId()
    if not HasActiveCompanion() then
        return nil
    end
    local companionId = GetActiveCompanionDefId()
    if companionId == nil or companionId == 0 then
        return nil
    end
    return companionId
end

-- Per-character data: level and rapport, which change with every kill or
-- rapport event. Kept cheap on purpose - no skill line walk, no name or perk
-- lookups. The rapport level's description text only changes when the level
-- does, so it's refreshed only then.
local function RecordActiveCompanionProgress()
    local companionId = GetActiveCompanionId()
    if companionId == nil then
        return
    end

    local character = GetOrCreateCharacterEntry(GetCharacterKey())
    local entry = character.companions[companionId] or {}

    local rapportLevel = GetActiveCompanionRapportLevel()
    if entry.name == nil then
        entry.name = zo_strformat("<<1>>", GetCompanionName(companionId))
    end
    entry.level = GetActiveCompanionLevelInfo()
    entry.rapportValue = GetActiveCompanionRapport()
    entry.rapportMax = GetMaximumRapport()
    if entry.rapportLevel ~= rapportLevel or entry.rapportLevelText == nil then
        entry.rapportLevelText = GetActiveCompanionRapportLevelDescription(rapportLevel)
    end
    entry.rapportLevel = rapportLevel
    entry.lastUpdated = GetTimeStamp()

    character.companions[companionId] = entry
    NotifyDataRecorded()
end

-- Account-wide data about a companion that doesn't depend on which character
-- you're on: the passive perk and the skill lines (a companion is the same
-- companion whichever character summons them), stored once in
-- savedVars.companionInfo[companionId]. `withPerk` also records the perk,
-- which never changes, so only the full captures ask for it. Skill lines are
-- only written when companion skills have initialized, so an early capture
-- can't wipe previously recorded ones with nil.
local function RecordActiveCompanionInfo(withPerk)
    local companionId = GetActiveCompanionId()
    if companionId == nil then
        return
    end

    local info = savedVars.companionInfo[companionId]
    if info == nil then
        info = {}
        savedVars.companionInfo[companionId] = info
    end

    if withPerk then
        local passivePerkId = GetCompanionPassivePerkAbilityId(companionId)
        info.passivePerkName = zo_strformat("<<1>>", GetAbilityName(passivePerkId))
        info.passivePerkDescription = GetAbilityDescription(passivePerkId)
    end

    local skillLines = GetActiveCompanionSkillLines()
    if skillLines then
        info.skillLines = skillLines
        info.skillLinesUpdated = GetTimeStamp()
    end
    NotifyDataRecorded()
end

local function RecordActiveCompanionFull()
    RecordActiveCompanionProgress()
    RecordActiveCompanionInfo(true)
end

-- Older versions stored the perk and skill lines inside every character's own
-- companion entry, one stale copy per character, and read an arbitrary one
-- back. Move them into savedVars.companionInfo once, keeping the copy with the
-- newest lastUpdated for each companion, then strip the per-character copies.
-- Rapport, level and the rapport level text stay per character.
local function MigrateCompanionInfo()
    if savedVars.companionInfoMigrated then
        return
    end

    for _, character in pairs(savedVars.characters) do
        for companionId, entry in pairs(character.companions) do
            local info = savedVars.companionInfo[companionId]
            if info == nil then
                info = {}
                savedVars.companionInfo[companionId] = info
            end

            local stamp = entry.lastUpdated or 0
            if entry.skillLines and stamp >= (info.skillLinesUpdated or -1) then
                info.skillLines = entry.skillLines
                info.skillLinesUpdated = stamp
            end
            if entry.passivePerkName and stamp >= (info.perkUpdated or -1) then
                info.passivePerkName = entry.passivePerkName
                info.passivePerkDescription = entry.passivePerkDescription
                info.perkUpdated = stamp
            end

            entry.skillLines = nil
            entry.passivePerkName = nil
            entry.passivePerkDescription = nil
        end
    end

    savedVars.companionInfoMigrated = true
end

-- Removes a line listed twice in the same skill group from the saved records
-- (the capture now refuses to record one, but a duplicate saved before that
-- would otherwise stay until the companion is next captured). Safe to run on
-- every load: it does nothing when there is nothing to remove.
local function DedupeStoredSkillLines()
    for _, info in pairs(savedVars.companionInfo) do
        for _, group in ipairs(info.skillLines or {}) do
            local seenNames, unique = {}, {}
            for _, line in ipairs(group.lines) do
                if not seenNames[line.name] then
                    seenNames[line.name] = true
                    table.insert(unique, line)
                end
            end
            if #unique ~= #group.lines then
                group.lines = unique
            end
        end
    end
end

-- Before saved data was split by server (the GetWorldName() namespace below)
-- it lived directly under the account's "$AccountWide" table. That old copy
-- is never read again but stays in the file; drop it once this server's
-- namespaced data exists. Only touches the old top-level `characters` and
-- `version` keys, never the namespaced tables.
local function RemoveUnnamespacedSavedData()
    local profile = CompanionRoster_SavedVariables and CompanionRoster_SavedVariables["Default"]
    local account = profile and profile[GetDisplayName()]
    local root = account and account["$AccountWide"]
    if root and root.characters ~= nil and root[GetWorldName()] ~= nil then
        root.characters = nil
        root.version = nil
    end
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
-- summoned, unlike rapport/level/perk, so this runs on every
-- EVENT_PLAYER_ACTIVATED (login, reload and each loading screen) for every
-- known companion rather than being event-driven per companion.
local function RecordIntroQuestCompletion()
    local character = GetOrCreateCharacterEntry(GetCharacterKey())
    for _, companion in ipairs(CompanionRoster.Data.GetAllCompanions()) do
        character.introQuestsDone[companion.id] = IsIntroQuestCompleteForActiveCharacter(companion.id)
    end
end

local cachesRefreshed = false

-- The rapport, XP and skill events only matter while a companion is out, so
-- they are registered only then (see SetCompanionEventsRegistered below).
local SetCompanionEventsRegistered

-- Called from the addon's single EVENT_PLAYER_ACTIVATED handler
-- (CompanionRoster.lua) on every activation: login, reload and each loading
-- screen. A reload or zone change fires no companion event, so this re-syncs
-- the event registration with a companion that may already be out.
function CompanionRoster.Data.OnPlayerActivated()
    -- Rebuild the companion list/map once from the now-ready game data
    -- instead of trusting anything built while the addon was still loading.
    if not cachesRefreshed then
        cachesRefreshed = true
        companionListCache = nil
        companionIdByCollectibleIdCache = nil
    end

    SetCompanionEventsRegistered(HasActiveCompanion())
    RecordActiveCompanionFull()
    RecordIntroQuestCompletion()
end

-- Rapport and XP events fire constantly (every kill), so they only refresh
-- the cheap per-character progress, not the perk or the skill lines.
local function OnCompanionRapportUpdate()
    RecordActiveCompanionProgress()
end

local function OnCompanionExperienceGain()
    RecordActiveCompanionProgress()
end

-- Summoning a companion captures everything. The event itself says a
-- companion is out, so it turns the other events on directly rather than
-- asking HasActiveCompanion() this early in the event.
local function OnCompanionActivated()
    SetCompanionEventsRegistered(true)
    RecordActiveCompanionFull()
end

local function OnCompanionDeactivated()
    SetCompanionEventsRegistered(false)
end

-- Companion skills initialize on their own timeline after summon (the
-- client's own source notes they're built and torn down as the active
-- companion changes) - re-capture here rather than waiting for a rapport
-- or XP event that might not happen this session.
local function OnCompanionSkillsFullUpdate()
    RecordActiveCompanionFull()
end

-- A skill line gaining a rank is the one skill change worth capturing
-- immediately (the roster's Level tooltip and the Guild rank shown by /fcr s
-- come from it).
local function OnCompanionSkillRankUpdate()
    RecordActiveCompanionInfo(false)
end

-- Skill XP ticks as often as kills do, and each capture walks every skill
-- line - so the first tick starts a short timer and the capture happens once
-- when it ends, however many ticks arrived meanwhile.
local SKILL_XP_CAPTURE_DELAY_MS = 5000
local skillXpCapturePending = false

local function OnCompanionSkillXpUpdate()
    if skillXpCapturePending then
        return
    end
    skillXpCapturePending = true
    zo_callLater(function()
        skillXpCapturePending = false
        RecordActiveCompanionInfo(false)
    end, SKILL_XP_CAPTURE_DELAY_MS)
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

-- The /fcr s and /fcr c results popup remembers its own position, separate
-- from the roster window's.
function CompanionRoster.Data.SaveResultsPosition(point, relativePoint, offsetX, offsetY)
    savedVars.resultsPosition = { point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
end

function CompanionRoster.Data.GetResultsPosition()
    return savedVars.resultsPosition
end

-- The popup is resizable; its size is remembered the same way.
function CompanionRoster.Data.SaveResultsSize(width, height)
    savedVars.resultsSize = { width = width, height = height }
end

function CompanionRoster.Data.GetResultsSize()
    return savedVars.resultsSize
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
-- closes the roster window when the player enters combat
-- (EVENT_PLAYER_COMBAT_STATE); see OnPlayerCombatState in CompanionRoster_UI.lua.
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

-- The colors for "done" (a maxed rapport or Guild line) and "in progress",
-- shared by every surface that shows that state - roster window, Collections
-- tiles and chat search results - so one setting recolors them all, plus
-- "tooltipLabel" for the labels in the Level tooltip. Chosen in the settings
-- panel, falling back to these defaults. Account-wide.
CompanionRoster.Data.DEFAULT_COLORS = {
    done = { 0.4, 1, 0.4 },
    inProgress = { 1, 0.8, 0.4 },
    tooltipLabel = { 1, 0.88, 0.3 }, -- the Guild:/Class:/... labels in the Level tooltip
}

-- Returns r, g, b (0-1) for "done" or "inProgress".
function CompanionRoster.Data.GetColor(kind)
    local saved = savedVars and savedVars.colors and savedVars.colors[kind]
    local color = saved or CompanionRoster.Data.DEFAULT_COLORS[kind]
    return color[1], color[2], color[3]
end

function CompanionRoster.Data.SetColor(kind, r, g, b)
    savedVars.colors = savedVars.colors or {}
    savedVars.colors[kind] = { r, g, b }
end

-- Same color as an "RRGGBB" string, for |c escape codes in chat and labels.
function CompanionRoster.Data.GetColorHex(kind)
    local r, g, b = CompanionRoster.Data.GetColor(kind)
    return string.format("%02X%02X%02X", zo_round(r * 255), zo_round(g * 255), zo_round(b * 255))
end

-- Companion Info frame (CompanionRoster_HUD.lua) preferences, account-wide.
-- Stored in one flat savedVars.hud table and read through GetHudOption so a
-- key that was never saved falls back to its default (a saved `false` stays
-- false, which is why this isn't `saved or default`).
CompanionRoster.Data.HUD_DEFAULTS = {
    enabled = true,
    bold = false,
    level = true,
    xpRaw = true,
    xpPercent = true,
    xpGain = true,
    rapportLevel = true,
    rapportChange = true,
    rapportNumber = true,
}

function CompanionRoster.Data.GetHudOption(key)
    local saved = savedVars and savedVars.hud and savedVars.hud[key]
    if saved == nil then
        return CompanionRoster.Data.HUD_DEFAULTS[key]
    end
    return saved
end

function CompanionRoster.Data.SetHudOption(key, value)
    savedVars.hud = savedVars.hud or {}
    savedVars.hud[key] = value
end

CompanionRoster.Data.DEFAULT_HUD_COLOR = { 1, 1, 1 }

-- Returns r, g, b (0-1) for the frame's text.
function CompanionRoster.Data.GetHudColor()
    local color = savedVars and savedVars.hudColor or CompanionRoster.Data.DEFAULT_HUD_COLOR
    return color[1], color[2], color[3]
end

function CompanionRoster.Data.SetHudColor(r, g, b)
    savedVars.hudColor = { r, g, b }
end

function CompanionRoster.Data.GetCompanionsForCharacter(characterKey)
    local character = savedVars.characters[characterKey]
    if character == nil then
        return {}
    end
    return character.companions
end

-- A companion's passive perk doesn't vary by character, unlike rapport and
-- level - so it's stored once, account-wide, in savedVars.companionInfo.
function CompanionRoster.Data.GetPassivePerkInfo(companionId)
    local info = savedVars.companionInfo[companionId]
    if info and info.passivePerkName then
        return info.passivePerkName, info.passivePerkDescription
    end
    return nil, nil
end

-- Companion skill progress is account-wide, like the passive perk above - one
-- shared copy in savedVars.companionInfo, whichever character recorded it last.
-- Returns nil if it was never recorded. Shape: an ordered list
-- of { typeName = "Class", lines = { { name = "Ardent Warrior", rank = 20 }, ... } }.
function CompanionRoster.Data.GetSkillLinesForCompanion(companionId)
    local info = savedVars.companionInfo[companionId]
    return info and info.skillLines or nil
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

    for _, group in ipairs(skillLines) do
        if CompanionRoster.Data.IsGuildSkillGroup(group) then
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

-- Summary of every one of a companion's Guild-type skill lines (name and
-- rank, plus "(Maxed)") - a companion can hold rank in more than one guild at
-- once (Fighters Guild/Mages Guild/Undaunted all independently), confirmed
-- live, so this lists all of them, not just the first found. General context
-- for deciding who to bring out, not tied to whatever term a rapport-tips
-- search matched. Returns nil if no Guild skill line has been recorded for
-- this companion yet (never summoned).
--
-- No XP figure: Guild ranks are handed out whole by quest completion, so a
-- companion's XP always sits exactly at the start of its rank (currentXP ==
-- lastRankXP in every recorded Guild line) and "x/y XP to next" could only
-- ever say 0.
function CompanionRoster.Data.GetGuildSkillLineSummary(companionId)
    local skillLines = CompanionRoster.Data.GetSkillLinesForCompanion(companionId)
    if skillLines == nil then
        return nil
    end

    for _, group in ipairs(skillLines) do
        if CompanionRoster.Data.IsGuildSkillGroup(group) then
            local summaryLines = {}
            for _, line in ipairs(group.lines) do
                local text = zo_strformat(COMPANIONROSTER_GUILD_RANK, line.name, line.rank)
                if line.isMaxed then
                    text = text .. " " .. GetString(COMPANIONROSTER_MAXED)
                end
                table.insert(summaryLines, text)
            end
            return #summaryLines > 0 and table.concat(summaryLines, "\n") or nil
        end
    end
    return nil
end

-- The player's own tag for how they've built a companion (Tank/Healer/DPS,
-- or a hybrid of two) - there's no API to derive this from gear or slotted
-- skills, it's purely a manual label. Stored account-wide (independent of
-- savedVars.characters) since a companion's actual build already is - see
-- GetSkillLinesForCompanion above. Values are nil (no role set) or one of
-- LFG_ROLE_TANK/LFG_ROLE_HEAL/LFG_ROLE_DPS, the same engine constants the
-- game's own Group Finder uses.
--
-- A hybrid is stored as a primary role in companionRoles (exactly where a
-- single role has always lived) plus an optional second role in
-- companionRolesSecondary. Keeping the primary where it was means data saved
-- before hybrids existed needs no migration, and an older Gear Hunter that
-- only reads the primary still shows a sensible icon.
--
-- Role names are the game's own (SI_LFGROLE: Damage, Tank, Healer), already
-- translated by the client.
local function GetRoleName(role)
    if role == nil then
        return nil
    end
    return GetString("SI_LFGROLE", role)
end

-- Every choice the right-click menu and settings panel offer, in display
-- order: the three single roles, then the three hybrids.
CompanionRoster.Data.ROLE_CHOICES = {
    { primary = LFG_ROLE_TANK },
    { primary = LFG_ROLE_HEAL },
    { primary = LFG_ROLE_DPS },
    { primary = LFG_ROLE_TANK, secondary = LFG_ROLE_DPS },
    { primary = LFG_ROLE_HEAL, secondary = LFG_ROLE_DPS },
    { primary = LFG_ROLE_TANK, secondary = LFG_ROLE_HEAL },
}

-- "Tank", or "Tank + Damage" for a hybrid; nil when there's no role.
function CompanionRoster.Data.GetRoleLabel(primary, secondary)
    local name = GetRoleName(primary)
    if name == nil then
        return nil
    end
    local secondaryName = GetRoleName(secondary)
    if secondaryName then
        name = zo_strformat(COMPANIONROSTER_ROLE_PAIR, name, secondaryName)
    end
    return name
end

-- Primary, secondary. Secondary is nil unless the companion is a hybrid.
function CompanionRoster.Data.GetCompanionRoles(companionId)
    return savedVars.companionRoles[companionId], savedVars.companionRolesSecondary[companionId]
end

function CompanionRoster.Data.SetCompanionRoles(companionId, primary, secondary)
    savedVars.companionRoles[companionId] = primary
    -- A second role only means something next to a different first role.
    if primary ~= nil and secondary ~= nil and secondary ~= primary then
        savedVars.companionRolesSecondary[companionId] = secondary
    else
        savedVars.companionRolesSecondary[companionId] = nil
    end
end

-- Kept so older callers (and an older Gear Hunter) keep working: the primary
-- role only, and setting a single role clears any second role.
function CompanionRoster.Data.GetCompanionRole(companionId)
    return savedVars.companionRoles[companionId]
end

function CompanionRoster.Data.SetCompanionRole(companionId, role)
    CompanionRoster.Data.SetCompanionRoles(companionId, role, nil)
end

-- Companion -> Keepsake collectible id. The Keepsake (Collections >
-- Upgrade > Companion Keepsakes) makes that companion's passive perk
-- always active, even when not summoned, once its meta-achievement is
-- done. No API derives this id from a companionId, so it's hardcoded -
-- found via chat-linking each one in-game (|H1:collectible:<id>|h|h).
-- Keyed by companionId (the name is in the comment beside each key), not by
-- name, since the displayed name depends on the client's language.
local KEEPSAKE_COLLECTIBLE_IDS = {
    [1] = 9457, -- Bastian Hallix
    [2] = 9458, -- Mirri Elendis
    [5] = 10436, -- Ember
    [6] = 10437, -- Isobel Veloise
    [8] = 11452, -- Sharp-as-Night
    [9] = 11453, -- Azandar
    [12] = 12227, -- Tanlorin
    [13] = 12228, -- Zerith-var
}

-- Account-wide, so this doesn't depend on which character is selected.
function CompanionRoster.Data.IsKeepsakeUnlocked(companionId)
    local collectibleId = KEEPSAKE_COLLECTIBLE_IDS[companionId]
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

-- Event name -> handler, for the events that only matter while a companion is
-- out. No event filter applies to any of them (none of these events has a
-- filterable parameter), so the handlers do their own checks where needed.
local COMPANION_EVENTS = {
    [EVENT_COMPANION_RAPPORT_UPDATE] = OnCompanionRapportUpdate,
    [EVENT_COMPANION_EXPERIENCE_GAIN] = OnCompanionExperienceGain,
    [EVENT_COMPANION_SKILLS_FULL_UPDATE] = OnCompanionSkillsFullUpdate,
    [EVENT_COMPANION_SKILL_RANK_UPDATE] = OnCompanionSkillRankUpdate,
    [EVENT_COMPANION_SKILL_XP_UPDATE] = OnCompanionSkillXpUpdate,
}
local EVENT_NAMESPACE = "CompanionRoster_Data"
local companionEventsRegistered = false

SetCompanionEventsRegistered = function(enabled)
    if enabled == companionEventsRegistered then
        return
    end
    companionEventsRegistered = enabled
    for eventCode, handler in pairs(COMPANION_EVENTS) do
        if enabled then
            EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, eventCode, handler)
        else
            EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, eventCode)
        end
    end
end

-- Called once from the addon's single EVENT_ADD_ON_LOADED handler
-- (CompanionRoster.lua), before anything else uses the saved data.
function CompanionRoster.Data.Initialize()
    -- GetWorldName() as the namespace splits saved data by server (EU/NA/PTS)
    -- rather than mixing it - matters because data here is keyed by
    -- character name, not character id, and the same @account can play on
    -- more than one server where two different characters could share a name.
    local defaults = { characters = {}, companionInfo = {}, companionRoles = {}, companionRolesSecondary = {}, slashCommand = "/fcr", closeOnCombat = false, showRoleOnCollections = true, showRapportOnCollections = true }
    savedVars = ZO_SavedVars:NewAccountWide("CompanionRoster_SavedVariables", CompanionRoster.savedVariablesVersion, GetWorldName(), defaults)
    savedVars.companionRolesSecondary = savedVars.companionRolesSecondary or {}
    savedVars.companionInfo = savedVars.companionInfo or {}
    MigrateCompanionInfo()
    DedupeStoredSkillLines()
    RemoveUnnamespacedSavedData()

    -- A companion being summoned or dismissed is what turns the rest on and off.
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_COMPANION_DEACTIVATED, OnCompanionDeactivated)
    SetCompanionEventsRegistered(HasActiveCompanion())
end
