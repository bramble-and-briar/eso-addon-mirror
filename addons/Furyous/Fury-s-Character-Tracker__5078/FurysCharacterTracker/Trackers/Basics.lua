-- shared
-- Who the character is: name, class, race, alliance, level, time played, achievement points.
local CT = FurysCharacterTracker
local U = CT.Util

-- The game's alliance badges (EsoUI/Common/Globals/AllianceToIcon.lua), by alliance ID.
local ALLIANCE_ICONS = {
    [1] = "EsoUI/Art/CharacterWindow/allianceBadge_aldmeri.dds",
    [2] = "EsoUI/Art/CharacterWindow/allianceBadge_ebonheart.dds",
    [3] = "EsoUI/Art/CharacterWindow/allianceBadge_daggerfall.dds",
}

-- Game only: the class's own icon.
local classIcons = {}
local function ClassIcon(e)
    local classId = e.c.classId
    if not classId or not CT.live then return nil end
    if classIcons[classId] == nil then
        local index = GetClassIndexById(classId)
        classIcons[classId] = index and select(7, GetClassInfo(index)) or false
    end
    return classIcons[classId] or nil
end

CT.Track({
    id = "basics",
    read = function(c)
        local gender = GetUnitGender("player")
        c.id = GetCurrentCharacterId()
        c.name = U.Plain(GetUnitName("player"))
        c.classId, c.class = GetUnitClassId("player"), U.Plain(GetUnitClass("player"))
        c.raceId, c.race = GetUnitRaceId("player"), U.Plain(GetUnitRace("player"))
        c.allianceId = GetUnitAlliance("player")
        c.alliance = U.Plain(GetAllianceName(c.allianceId))
        c.level = GetUnitLevel("player")
        c.gender = gender
        c.playedHours = zo_round(GetSecondsPlayed() / 3600)
        c.achievementPoints = GetEarnedAchievementPoints()
    end,
    events = { EVENT_ACHIEVEMENT_AWARDED },
    start = function(queue)
        EVENT_MANAGER:RegisterForEvent(CT.name .. "Level", EVENT_LEVEL_UPDATE, queue)
        EVENT_MANAGER:AddFilterForEvent(CT.name .. "Level", EVENT_LEVEL_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    end,
    columns = {
        { key = "name", title = "Character", width = 184, align = "left", value = function(e) return e.name end,
          head = "Your characters. Click one for everything saved about it. Right-click for the menu.",
          tip = function(e)
              local c = e.c
              local text = string.format("%s\nLevel %s %s %s\nRead from the game %s (%s)", e.name, c.level or "?", c.race or "", c.class or "",
                                         U.Ago(c.lastScan), U.FormatDate(c.lastScan))
              if e.m.note then text = text .. "\n\nNote: " .. e.m.note end
              return text .. "\n\nClick for details. Right-click for the menu."
          end },
        { key = "class", title = "Class", width = 120, align = "left", value = function(e) return e.c.class or "" end, icon = ClassIcon,
          head = "The character's class." },
        { key = "race", title = "Race", width = 96, align = "left", value = function(e) return e.c.race or "" end, head = "The character's race." },
        { key = "alliance", title = "Alliance", width = 120, align = "left", value = function(e) return e.c.alliance or "" end,
          -- The badge says the rest: "Daggerfall Covenant" is shown as "Daggerfall".
          display = function(v) return (v:gsub(" Covenant$", ""):gsub(" Pact$", ""):gsub(" Dominion$", "")) end,
          icon = function(e) return ALLIANCE_ICONS[e.c.allianceId] end, head = "The character's alliance.",
          tip = function(e) return e.c.alliance or "" end },
        { key = "level", title = "Level", width = 60, max = 50, value = function(e) return e.c.level or 0 end,
          head = "Character level. 50 is the top; after that it is Champion Points, which the whole account shares." },
        { key = "achievements", title = "Ach. points", width = 84, value = function(e) return e.c.achievementPoints or 0 end,
          head = "Achievement points earned on this character.",
          display = function(v) return U.Comma(v) end,
          tip = function(e) return "Achievement points: " .. U.Comma(e.c.achievementPoints) end },
        { key = "hours", title = "Hours", width = 76, sum = true, value = function(e) return e.c.playedHours or 0 end,
          display = function(v) return U.Comma(v) end, tip = "Hours played (/played)", head = "Hours played on this character." },
        { key = "updated", title = "Updated", width = 96, value = function(e) return U.FormatDate(e.c.lastScan) end,
          head = "Updated: the last day this character was read from the game.",
          tip = function(e) return "Read from the game " .. U.Ago(e.c.lastScan) .. ".\n/fct unread lists the characters that are out of date." end },
    },
    summary = function(e)
        return { { "Achievement points", U.Comma(e.c.achievementPoints) }, { "Hours played", U.Comma(e.c.playedHours) } }
    end,
    export = {
        { "Character", function(e) return e.name end }, { "Class", function(e) return e.c.class end },
        { "Race", function(e) return e.c.race end }, { "Alliance", function(e) return e.c.alliance end },
        { "Level", function(e) return e.c.level end },
        { "Achievement points", function(e) return e.c.achievementPoints end }, { "Hours played", function(e) return e.c.playedHours end },
        { "Updated", function(e) return U.FormatDate(e.c.lastScan) end },
    },
})
