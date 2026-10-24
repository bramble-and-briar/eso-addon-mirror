local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
local function FindFreeId(tab)
    local i = 1
    while (tab[i] ~= nil) do
        i = i + 1
    end
    return i
end
CAE.FindFreeId = FindFreeId


---------------------------------------------------------------------
function CAE.CreateProfile()
    local id = FindFreeId(CAE.profiles)

    CAE.profiles[id] = {
        profileName = "Profile " .. id,
        circles = {},
        lines = {},
        hungerRequireModifier = false,
        lowerHunger = false,
        higherFrenzyAndAtro = false,
        evenHigherFrenzy = false,
        iconsForKnownPets = false,
        iconsForPets = false,
        iconsForCompanions = false,
        damagedEnemies = false,
    }

    -- Select new
    CAE.csvs.currentProfile = id

    return id
end

function CAE.DuplicateProfile()
    local id = FindFreeId(CAE.profiles)

    CAE.profiles[id] = ZO_DeepTableCopy(CAE.profiles[CAE.csvs.currentProfile])
    CAE.profiles[id].profileName = "Copy of " .. CAE.profiles[id].profileName

    -- Select new
    CAE.csvs.currentProfile = id

    return id
end

function CAE.DeleteProfile(id)
    CAE.profiles[id] = nil

    -- Change all that were using this profile to the default
    local svs = CrutchAlertsExtensionsSavedVariables
    for _, serverData in pairs(svs) do
        for _, accData in pairs(serverData) do
            for _, charData in pairs(accData) do
                if (charData.currentProfile == id) then
                    charData.currentProfile = -1
                end
            end
        end
    end
end
