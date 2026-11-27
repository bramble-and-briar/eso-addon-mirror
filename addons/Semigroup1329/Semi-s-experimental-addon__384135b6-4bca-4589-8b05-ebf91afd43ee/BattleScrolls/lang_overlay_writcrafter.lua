if not SemisPlaygroundCheckAccess() then return end

-- Dolgubon's Lazy Writ Crafter recognises hireling mail by its subject and a
-- crafting station by the name under the reticle, comparing both with text it
-- carries for the official languages. The overlay translates those, so in the
-- overlay language its mail looting and reticle colouring find nothing. Under
-- an unofficial language it loads its English file ($(officialLanguage)), and
-- everything else it reads (quests, dialogue) stays English in the overlay.
--
-- The manifest lists the add-on as an optional dependency, so when it is
-- installed it has loaded and initialised before this file runs.

---@class LangOverlayWritCrafter
---@field hirelingMailSubjects table<string, boolean>|nil
---@field langStationNames (fun(): table<string, integer>)|nil
---@field initializeReticleChanges fun()|nil

-- Set by lang_overlay_<language>.lua, which exists for the overlay language only.
local texts = BattleScrolls.langOverlayTexts
local writCrafter = rawget(_G, 'WritCreater') ---@type LangOverlayWritCrafter|nil
if not texts or not writCrafter then return end

-- Its mail handler keeps a reference to this table, so new keys reach it.
local subjects = writCrafter.hirelingMailSubjects
if subjects then
    local translated = {}
    for english in pairs(subjects) do
        translated[#translated + 1] = texts[english]
    end
    for _, subject in ipairs(translated) do
        subjects[subject] = true
    end
end

-- initializeReticleChanges() reads the station names once and keeps them in the
-- wrapper it puts around the reticle's SetText, out of reach. A second run with
-- the translated names adds a wrapper that knows them; the first one then
-- matches nothing and passes the text through.
local nativeStationNames = writCrafter.langStationNames
if nativeStationNames and writCrafter.initializeReticleChanges then
    local stations = {}
    for english, craftingType in pairs(nativeStationNames()) do
        local translated = texts[english]
        if translated then
            stations[translated] = craftingType
        end
    end
    if next(stations) then
        writCrafter.langStationNames = function() return stations end
        writCrafter.initializeReticleChanges()
        writCrafter.langStationNames = nativeStationNames
    end
end
