PullCardData = PullCardData or {}
PullCardData.encounters = {}
PullCardData.dungeons = {}
PullCardData.dungeonOrder = {}

-- Top-level menu sections, in display order.
PullCardData.CATEGORIES = {
    { key = "base", name = "Base Game Dungeons" },
    { key = "dlc", name = "DLC Dungeons" },
    { key = "trial", name = "Trials" },
    { key = "arena", name = "Group Arenas" },
    { key = "solo", name = "Solo Arenas" },
}

-- Registers a dungeon or trial. Must be called before its encounters.
--   category: "base" | "dlc" | "trial" | "arena" (group arenas) | "solo" (solo arenas, use addRound)
--   opts.group:  DLC/chapter name, shown in the menu label (e.g. "Wolfhunter")
--   opts.zoneId: GetZoneId() of the instance; when set, it is used instead of
--                the zone name to match the player's location (see debug view)
function PullCardData.addDungeon(name, category, opts)
    opts = opts or {}
    local dungeon = {
        name = name,
        category = category,
        group = opts.group,
        zoneId = opts.zoneId,
        encounters = {},
    }
    PullCardData.dungeons[name] = dungeon
    table.insert(PullCardData.dungeonOrder, dungeon)
end

-- One entry per encounter, in run order. Every NPC name in `names` (plus aliases)
-- maps to this card. The same NPC name may appear in several dungeons; the
-- player's current zone picks the card.
--   extra.hardmode:   how hard mode changes the fight (shown on the card on Veteran)
--   extra.challenges: list of { name = "Achievement name" (optional), text = "..." }
function PullCardData.addShared(names, dungeonName, title, aliases, summary, everyone, tank, healer, dps, tldr, extra)
    extra = extra or {}
    local dungeon = PullCardData.dungeons[dungeonName]
    if not dungeon then
        -- Keep the card usable even if addDungeon was forgotten.
        PullCardData.addDungeon(dungeonName, "other")
        dungeon = PullCardData.dungeons[dungeonName]
    end

    local encounter = {
        dungeon = dungeonName,
        dungeonInfo = dungeon,
        title = title,
        names = names,
        aliases = aliases or {},
        summary = summary,
        everyone = everyone,
        tank = tank,
        healer = healer,
        dps = dps,
        tldr = tldr,
        hardmode = extra.hardmode,
        challenges = extra.challenges or {},
    }
    table.insert(PullCardData.encounters, encounter)
    table.insert(dungeon.encounters, encounter)
end

function PullCardData.addBoss(name, ...)
    PullCardData.addShared({name}, ...)
end

-- Name of the achievement for beating a boss on hard mode, so the card can show
-- whether the player has done it. Drops a duplicate challenge of the same name.
function PullCardData.setHardModeAchievement(dungeonName, bossTitle, achievementName)
    local dungeon = PullCardData.dungeons[dungeonName]
    if not dungeon then return end
    for _, encounter in ipairs(dungeon.encounters) do
        if encounter.title == bossTitle then
            encounter.hardmodeAchievement = achievementName
            for i = #encounter.challenges, 1, -1 do
                if encounter.challenges[i].name == achievementName then
                    table.remove(encounter.challenges, i)
                end
            end
            return
        end
    end
end

-- Adds (or replaces) a boss's hard mode text along with its achievement.
function PullCardData.setHardMode(dungeonName, bossTitle, text, achievementName)
    local dungeon = PullCardData.dungeons[dungeonName]
    if not dungeon then return end
    for _, encounter in ipairs(dungeon.encounters) do
        if encounter.title == bossTitle then
            encounter.hardmode = text
            break
        end
    end
    PullCardData.setHardModeAchievement(dungeonName, bossTitle, achievementName)
end

-- Dungeon-wide achievements (Veteran clear, hard mode, speed run, no death...),
-- listed with done/not done in the Dungeon Overview.
function PullCardData.setDungeonAchievements(dungeonName, names)
    local dungeon = PullCardData.dungeons[dungeonName]
    if not dungeon then return end
    dungeon.achievements = names
end

-- Overland zone the dungeon's entrance is in.
function PullCardData.setLocation(dungeonName, zone)
    local dungeon = PullCardData.dungeons[dungeonName]
    if dungeon then dungeon.location = zone end
end

-- What drops in a dungeon: its item sets and its monster set (mask from the
-- final boss on Veteran, shoulders from the Undaunted).
function PullCardData.setDrops(dungeonName, sets, monsterSet)
    local dungeon = PullCardData.dungeons[dungeonName]
    if not dungeon then return end
    dungeon.sets = sets
    dungeon.monsterSet = monsterSet
end

-- Solo arena round. Pops when the player enters `area` (the subzone/map name the
-- game shows for that round) instead of when a boss frame appears. `area` may be
-- a list when the game uses more than one name for a round. No role lines: solo
-- content.
function PullCardData.addRound(arenaName, area, title, summary, mechanics, tldr, extra)
    PullCardData.addShared({}, arenaName, title, {}, summary, mechanics, nil, nil, nil, tldr, extra)
    local encounters = PullCardData.encounters
    encounters[#encounters].area = type(area) == "table" and area or { area }
end
