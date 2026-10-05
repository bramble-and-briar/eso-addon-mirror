-- Owned titles: lookup and display text.
local FT = Flexatron
local Titles = {}
FT.Titles = Titles

-- Every title this character has unlocked, as { index = i, name = raw name }.
function Titles.GetOwned()
    local owned = {}
    for i = 1, GetNumTitles() do
        local name = GetTitle(i)
        if name and name ~= "" then
            owned[#owned + 1] = { index = i, name = name }
        end
    end
    return owned
end

-- A title name as the player reads it (gendered forms resolved for this character).
function Titles.Format(name)
    return zo_strformat(name, GetRawUnitName("player"))
end

-- Every unlocked title's index by its name and by the name as the player reads it, built in one
-- pass. Titles are only ever added, and indexes shift when they are, so a change in the count
-- means building it again.
local lookup -- { count, byName = { [name] = index }, byDisplay = { [display name] = index } }

local function Lookup()
    local count = GetNumTitles()
    if not lookup or lookup.count ~= count then
        lookup = { count = count, byName = {}, byDisplay = {} }
        for i = 1, count do
            local name = GetTitle(i)
            if name and name ~= "" then
                lookup.byName[name] = lookup.byName[name] or i
                local display = Titles.Format(name)
                lookup.byDisplay[display] = lookup.byDisplay[display] or i
            end
        end
    end
    return lookup
end

-- Index of the unlocked title with this name, or nil. Settings store titles by name, since
-- indexes shift when titles unlock; names from achievements may already be formatted.
function Titles.IndexOf(name)
    if not name or name == "" then
        return nil
    end
    local found = Lookup()
    return found.byName[name] or found.byDisplay[Titles.Format(name)]
end
