local AH = _G.MarkTrialHelper

local function needsUpdate(version)
    if (not AH.Vars.Updates[version]) then
        return true
    end

    return false
end

function AH.VersionCheck()
    AH.Vars.Updates = AH.Vars.Updates or {}

    if (needsUpdate(1103)) then
        if (AH.Vars.GWCheck) then
            AH.Vars.GwCheck = AH.Vars.GWCheck
            AH.Vars.GWCheck = nil
        end

        AH.Vars.Updates[1103] = true
    end
end