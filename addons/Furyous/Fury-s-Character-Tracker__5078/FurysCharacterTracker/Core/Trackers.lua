-- shared
-- The list of tracked things. Each file in Trackers/ calls CT.Track once (or once per part) with:
--
--   id        short name of the part ("riding", "wallet")
--   read      function(c, account): reads it from the game into the character's saved table `c`
--             (or into `account` for numbers the whole account shares). Game calls go only in here.
--   events    game events after which it is read again
--   start     function(queue, current): for events that need more care than "read it again".
--             queue() asks for a new read in a few seconds (queue(true): at once); current() is the
--             saved table of the character you are on.
--   columns   board columns (the fields of a column are listed in Core/Board.lua).
--             A tab shows a column by naming its key in Data/Views.lua.
--   summary   function(e): items for the "Progress" block of the details window
--   sections  function(e): its own blocks in the details window
--   export    { { "Column title", function(e) return value end }, ... } for the Excel export
--
-- `e` is a board entry: { id =, name =, c = saved character, m = your picks }.
-- To track something new: add a file here, list it in the manifest, and name its column keys in
-- a tab in Data/Views.lua. Nothing else needs to change, in game or in the offline viewer.
local CT = FurysCharacterTracker
local Trackers = { list = {}, byId = {}, columns = {} }
CT.Trackers = Trackers

function CT.Track(def)
    Trackers.list[#Trackers.list + 1] = def
    Trackers.byId[def.id] = def
    for _, column in ipairs(def.columns or {}) do
        column.tracker = def.id
        Trackers.columns[column.key] = column
    end
    return def
end

function Trackers.Column(key)
    return Trackers.columns[key]
end

-- Columns shared by every tab are made once; a tab names them by key.
function Trackers.Columns(keys)
    local list = {}
    for _, key in ipairs(keys) do
        local column = Trackers.columns[key]
        if column then list[#list + 1] = column end
    end
    return list
end

-- "x of y" items for the details window.
-- { key, value text, done = true when complete, dim = true when nothing yet }
function Trackers.Progress(key, value, max)
    value = value or 0
    local U = CT.Util
    local text = max and (U.Comma(value) .. " / " .. U.Comma(max)) or U.Comma(value)
    return { key, text, done = (max ~= nil and value >= max), dim = value == 0 }
end
