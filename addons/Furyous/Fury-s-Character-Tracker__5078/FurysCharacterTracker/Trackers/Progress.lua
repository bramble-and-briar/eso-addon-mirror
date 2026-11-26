-- shared
-- Progress over time: what each character gained in the last 7 and 30 days. Nothing is read from
-- the game here; it compares today's numbers with the daily lines kept by Core/History.lua.
local CT = FurysCharacterTracker
local U = CT.Util
local H = CT.History

local FIELDS = {
    { field = "gold", title = "Gold", what = "Gold carried", width = 96, short = true },
    { field = "playedHours", title = "Hours", what = "Hours played", width = 76 },
    { field = "skillPoints", title = "Skill pts", what = "Skill points earned", width = 88 },
    { field = "achievementPoints", title = "Ach. pts", what = "Achievement points", width = 92 },
    { field = "research", title = "Traits", what = "Traits researched", width = 76 },
}

local function Delta(e, field, days)
    return H.Delta(CT.Data(), e.id, e.c, field, days)
end

-- "+1,234", "+45k" for the wide ones, "-" for no change.
local function Change(v, short)
    if v == 0 then return "-" end
    if short then return (v > 0 and "+" or "") .. U.Short(v) end
    return U.Signed(v)
end

local function Column(def, days)
    return { key = string.format("delta.%s.%d", def.field, days), title = string.format("%s %dd", def.title, days), width = def.width, sum = true,
             head = string.format("%s: the change over the last %d days.\nA character tracked for less time than that shows the change since its first day.", def.what, days),
             value = function(e) return Delta(e, def.field, days) or 0 end,
             display = function(v) return Change(v, def.short) end, total = function(sum) return Change(sum, def.short) end,
             dim = function(v) return v == 0 end,
             tip = function(e)
                 local delta, day = Delta(e, def.field, days)
                 if not delta then return "Nothing to compare with yet.\nA line is saved for every day you play this character, starting with this version." end
                 return string.format("%s: %s since %s\nNow: %s", def.what, U.Signed(delta), H.DayText(day), U.Comma(e.c[def.field]))
             end }
end

local columns = {}
for _, def in ipairs(FIELDS) do
    columns[#columns + 1] = Column(def, 7)
    columns[#columns + 1] = Column(def, 30)
end
columns[#columns + 1] = {
    key = "trackedSince", title = "Tracked since", width = 112,
    head = "Tracked since: the first day this character's progress was saved.",
    value = function(e) local day = H.Since(CT.Data(), e.id); return day and H.DayText(day) or "" end,
    display = function(v) return v == "" and "-" or v end, dim = function(v) return v == "" end,
    tip = function(e)
        local list = CT.Data().history[e.id]
        if not list or #list == 0 then return "Tracking starts the next time you log in on this character." end
        return U.Count(#list, "day") .. " saved, one for every day you played this character."
    end }

CT.Track({
    id = "progress",
    columns = columns,
    sections = function(e)
        local items = {}
        for _, def in ipairs(FIELDS) do
            for _, days in ipairs({ 7, 30 }) do
                local delta = Delta(e, def.field, days)
                if delta then items[#items + 1] = { string.format("%s, %d days", def.what, days), U.Signed(delta), dim = delta == 0 } end
            end
        end
        if #items == 0 then return nil end
        return { { title = "Progress over time", items = items } }
    end,
})
