-- shared
-- What only you know about a character: role, the gear you have farmed, a planned race, a note.
-- Nothing is read from the game here; the cells are yours to fill (click a blue one).
local CT = FurysCharacterTracker
local F = CT.Roster.FIELDS

local function Pick(key, width, field, tip)
    return { key = key, title = F[field].title, width = width, value = function(e) return e.m[field] or "" end,
             pick = { field = field, values = F[field].values }, tip = tip,
             head = F[field].title .. ": your own pick. Click a cell to choose.\n" .. tip }
end

CT.Track({
    id = "picks",
    columns = {
        -- The role as plain text, for the tabs where it is not the point.
        { key = "role", title = "Role", width = 88, value = function(e) return e.m.role or "" end,
          head = "Role: your own pick. Change it on the Roles & gear tab.", tip = function(e) return e.m.role end },
        Pick("rolePick", 124, "role", "The role(s) you play this character in."),
        Pick("dpsGear", 108, "dpsGear", "The DPS gear you have farmed for this character."),
        Pick("roleGear", 124, "roleGear", "The tank or healer gear you have farmed for this character.\nFor a DPS/Healer: DPS gear = DPS role, this = healer role."),
        Pick("plannedRace", 100, "plannedRace", "A race change you plan (blank = none)."),
        { key = "note", title = "Note", width = 180, align = "left", note = true, value = function(e) return e.m.note or "" end,
          head = "Note: anything you want to remember about this character. Click a cell to write one.",
          tip = function(e) return (e.m.note or "No note yet.") .. "\n\nClick to edit." end },
    },
    sections = function(e)
        local m = e.m
        local section = { title = "Your picks", items = {
            { "Role", m.role or "-" }, { "DPS gear", m.dpsGear or "-" },
            { "Tank/healer gear", m.roleGear or "-" }, { "Planned race", m.plannedRace or "-" } } }
        if m.note then section.lines = { "Note: " .. m.note } end
        return { section }
    end,
    export = {
        { "Role", function(e) return e.m.role end }, { "DPS gear", function(e) return e.m.dpsGear end },
        { "Tank/healer gear", function(e) return e.m.roleGear end }, { "Planned race", function(e) return e.m.plannedRace end },
        { "Note", function(e) return e.m.note end },
    },
})
