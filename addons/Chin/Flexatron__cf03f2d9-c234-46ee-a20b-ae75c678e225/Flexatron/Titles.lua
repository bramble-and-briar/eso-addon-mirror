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

-- Index of the unlocked title with this name, or nil. Settings store titles by name, since
-- indexes shift when titles unlock; names from achievements may already be formatted.
function Titles.IndexOf(name)
    if not name or name == "" then
        return nil
    end
    local count = GetNumTitles()
    for i = 1, count do
        if GetTitle(i) == name then
            return i
        end
    end
    local display = Titles.Format(name)
    for i = 1, count do
        if Titles.Format(GetTitle(i)) == display then
            return i
        end
    end
    return nil
end
