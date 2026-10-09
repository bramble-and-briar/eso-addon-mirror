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

-- Solo arena round. Pops when the player enters `area` (the subzone/map name the
-- game shows for that round) instead of when a boss frame appears. `area` may be
-- a list when the game uses more than one name for a round. No role lines: solo
-- content.
function PullCardData.addRound(arenaName, area, title, summary, mechanics, tldr, extra)
    PullCardData.addShared({}, arenaName, title, {}, summary, mechanics, nil, nil, nil, tldr, extra)
    local encounters = PullCardData.encounters
    encounters[#encounters].area = type(area) == "table" and area or { area }
end
